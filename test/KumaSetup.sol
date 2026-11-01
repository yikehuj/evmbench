// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {AccessController} from "@mcag/AccessController.sol";
import {Blacklist} from "@mcag/Blacklist.sol";
import {MCAGAggregator, MCAGAggregatorInterface} from "@mcag/MCAGAggregator.sol";
import {KUMABondToken} from "@mcag/KUMABondToken.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {KUMAAccessController} from "@kuma/KUMAAccessController.sol";
import {KUMAAddressProvider} from "@kuma/KUMAAddressProvider.sol";
import {KBCToken} from "@kuma/KBCToken.sol";
import {KIBToken} from "@kuma/KIBToken.sol";
import {KUMASwap} from "@kuma/KUMASwap.sol";
import {KUMAFeeCollector} from "@kuma/KUMAFeeCollector.sol";
import {MCAGRateFeed} from "@kuma/MCAGRateFeed.sol";
import {MockERC20} from "@kuma/mocks/MockERC20.sol";
import {Roles} from "@kuma/libraries/Roles.sol";
import {IKUMABondToken} from "@mcag/interfaces/IKUMABondToken.sol";

/// @notice Shared deployment harness for the exploit tests.
/// @dev Deliberately uses low-level ABI initialization for the rate feed: the
/// M-03 gold patch changes `initialize(address)` to
/// `initialize(address,uint256)`, and this harness must compile against both
/// the vulnerable and the patched source tree.
abstract contract KumaSetup is Test {
    using Roles for bytes32;

    bytes16 internal constant _CUSIP = bytes16("037833100");
    bytes16 internal constant _ISIN = bytes16("US0378331005");
    bytes4 internal constant _CURRENCY = "EUR";
    bytes4 internal constant _COUNTRY = "FR";
    uint64 internal constant _TERM = 365 days * 30;
    bytes32 internal constant _RISK_CATEGORY = keccak256(abi.encode(_CURRENCY, _COUNTRY, _TERM));
    uint256 internal constant _YIELD = 1000000001547125957863212449; // ~5% per year, ray
    uint256 internal constant _EPOCH_LENGTH = 4 hours;

    IAccessControl internal _mcagAccessController;
    IAccessControl internal _KUMAAccessController;
    Blacklist internal _blacklist;
    MockERC20 internal _deprecationStableCoin;
    MCAGAggregator internal _mcagAggregator;
    KUMAAddressProvider internal _KUMAAddressProvider;
    KUMABondToken internal _KUMABondToken;
    KBCToken internal _KBCToken;
    KIBToken internal _KIBToken;
    KUMASwap internal _KUMASwap;
    KUMAFeeCollector internal _KUMAFeeCollector;
    MCAGRateFeed internal _rateFeed;

    address internal _alice = vm.addr(1);
    address internal _bob = vm.addr(2);

    function _deployWorld() internal {
        vm.warp(365 days * 30);

        // MCAG side: AccessController grants every MCAG role to its deployer.
        _mcagAccessController = IAccessControl(address(new AccessController()));
        _mcagAggregator = new MCAGAggregator(
            "30 YEAR FR TREASURY", int256(2e27), _mcagAccessController
        );
        _mcagAggregator.transmit(int256(_YIELD));

        // KUMA side.
        _KUMAAccessController = IAccessControl(address(new KUMAAccessController()));
        _blacklist = new Blacklist(_mcagAccessController);

        _KUMAAddressProvider = KUMAAddressProvider(
            _proxy(
                address(new KUMAAddressProvider()),
                abi.encodeWithSelector(
                    KUMAAddressProvider.initialize.selector, address(_KUMAAccessController)
                )
            )
        );

        _KBCToken = KBCToken(
            _proxy(
                address(new KBCToken()),
                abi.encodeWithSelector(
                    KBCToken.initialize.selector, address(_KUMAAddressProvider)
                )
            )
        );

        _KIBToken = KIBToken(
            _proxy(
                address(new KIBToken()),
                abi.encodeWithSelector(
                    KIBToken.initialize.selector,
                    "KUMA Interest Bearing Token",
                    "FRK360",
                    _EPOCH_LENGTH,
                    address(_KUMAAddressProvider),
                    _CURRENCY,
                    _COUNTRY,
                    _TERM
                )
            )
        );

        _deprecationStableCoin = new MockERC20();

        _KUMASwap = KUMASwap(
            _proxy(
                address(new KUMASwap()),
                abi.encodeWithSelector(
                    KUMASwap.initialize.selector,
                    address(_KUMAAddressProvider),
                    address(_deprecationStableCoin),
                    _CURRENCY,
                    _COUNTRY,
                    _TERM
                )
            )
        );

        _KUMABondToken = new KUMABondToken(_mcagAccessController, _blacklist);

        _KUMAFeeCollector = KUMAFeeCollector(
            _proxy(
                address(new KUMAFeeCollector()),
                abi.encodeWithSelector(
                    KUMAFeeCollector.initialize.selector,
                    address(_KUMAAddressProvider),
                    _CURRENCY,
                    _COUNTRY,
                    _TERM
                )
            )
        );

        _rateFeed = _deployRateFeed();

        skip(_EPOCH_LENGTH);

        _KUMAAccessController.grantRole(
            Roles.KUMA_MINT_ROLE.toGranularRole(_RISK_CATEGORY), address(_KUMASwap)
        );
        _KUMAAccessController.grantRole(
            Roles.KUMA_BURN_ROLE.toGranularRole(_RISK_CATEGORY), address(_KUMASwap)
        );

        _KUMAAddressProvider.setKBCToken(address(_KBCToken));
        _KUMAAddressProvider.setKUMABondToken(address(_KUMABondToken));
        _KUMAAddressProvider.setRateFeed(address(_rateFeed));
        _KUMAAddressProvider.setKIBToken(_CURRENCY, _COUNTRY, _TERM, address(_KIBToken));
        _KUMAAddressProvider.setKUMASwap(_CURRENCY, _COUNTRY, _TERM, address(_KUMASwap));
        _KUMAAddressProvider.setKUMAFeeCollector(
            _CURRENCY, _COUNTRY, _TERM, address(_KUMAFeeCollector)
        );

        _rateFeed.setOracle(
            _CURRENCY, _COUNTRY, _TERM, MCAGAggregatorInterface(address(_mcagAggregator))
        );
    }

    /// @dev Tries the patched two-argument initializer first and falls back to
    /// the vulnerable one-argument initializer. A failed proxy creation is
    /// rolled back, so the fallback starts from clean storage.
    function _deployRateFeed() private returns (MCAGRateFeed rateFeed) {
        address implementation = address(new MCAGRateFeed());
        try new ERC1967Proxy(
            implementation,
            abi.encodeWithSignature(
                "initialize(address,uint256)", address(_KUMAAccessController), type(uint256).max
            )
        ) returns (ERC1967Proxy proxy) {
            return MCAGRateFeed(address(proxy));
        } catch {
            return MCAGRateFeed(
                address(
                    new ERC1967Proxy(
                        implementation,
                        abi.encodeWithSignature(
                            "initialize(address)", address(_KUMAAccessController)
                        )
                    )
                )
            );
        }
    }

    function _proxy(address implementation, bytes memory data) internal returns (address) {
        return address(new ERC1967Proxy(implementation, data));
    }

    function _bond() internal view returns (IKUMABondToken.Bond memory) {
        return IKUMABondToken.Bond({
            cusip: _CUSIP,
            isin: _ISIN,
            currency: _CURRENCY,
            country: _COUNTRY,
            term: _TERM,
            issuance: uint64(block.timestamp),
            maturity: uint64(block.timestamp + _TERM),
            coupon: _YIELD,
            principal: 10 ether,
            riskCategory: _RISK_CATEGORY
        });
    }
}

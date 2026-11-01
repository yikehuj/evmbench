// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import "permit2/interfaces/IPermit2.sol";

import "../src/V3Vault.sol";
import "../src/InterestRateModel.sol";
import "../src/interfaces/IV3Oracle.sol";
import "../src/interfaces/IInterestRateModel.sol";

import "./mocks/Mocks.sol";

abstract contract Harness is Test {
    uint256 internal constant Q32 = 2 ** 32;
    uint256 internal constant Q96 = 2 ** 96;
    uint32 internal constant CF90 = 3865470566; // 90% * Q32
    uint256 internal constant HUGE = 1e30;

    MockERC20 internal asset;
    MockNPM internal npm;
    MockOracle internal oracle;
    InterestRateModel internal irm;
    MockPermit2 internal permit2;
    V3Vault internal vault;

    address internal lender;
    address internal borrower;
    address internal liquidator;
    address internal token0;
    address internal token1;

    bytes4 internal constant OLD_LIQUIDATE_SELECTOR =
        bytes4(keccak256("liquidate((uint256,uint256,uint256,uint256,address,bytes))"));
    bytes4 internal constant NEW_LIQUIDATE_SELECTOR =
        bytes4(keccak256("liquidate((uint256,uint256,uint256,address,bytes))"));

    struct LiquidateParamsOld {
        uint256 tokenId;
        uint256 debtShares;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        bytes permitData;
    }

    struct LiquidateParamsNew {
        uint256 tokenId;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        bytes permitData;
    }

    function setUp() public virtual {
        lender = address(this);
        borrower = makeAddr("borrower");
        liquidator = makeAddr("liquidator");
        token0 = address(uint160(0x1001));
        token1 = address(uint160(0x1002));

        asset = new MockERC20("Mock USD", "mUSD", 6);
        npm = new MockNPM();
        oracle = new MockOracle(token0, token1);
        irm = new InterestRateModel(Q96 / 10, Q96 * 2, Q96 * 2, Q96 * 8 / 10);
        permit2 = new MockPermit2();

        vault = new V3Vault(
            "Revert Lend Vault",
            "rlV",
            address(asset),
            INonfungiblePositionManager(address(npm)),
            IInterestRateModel(address(irm)),
            IV3Oracle(address(oracle)),
            IPermit2(address(permit2))
        );

        vault.setTokenConfig(token0, CF90, type(uint32).max);
        vault.setTokenConfig(token1, CF90, type(uint32).max);
    }

    function _setLimits(
        uint256 minLoanSize,
        uint256 globalLendLimit,
        uint256 globalDebtLimit,
        uint256 dailyLendIncreaseLimitMin,
        uint256 dailyDebtIncreaseLimitMin
    ) internal {
        vault.setLimits(
            minLoanSize, globalLendLimit, globalDebtLimit, dailyLendIncreaseLimitMin, dailyDebtIncreaseLimitMin
        );
    }

    function _fundLender(uint256 amount) internal {
        asset.mint(lender, amount);
        asset.approve(address(vault), type(uint256).max);
    }

    function _deposit(uint256 amount) internal {
        _fundLender(amount);
        vault.deposit(amount, lender);
    }

    function _createLoan(uint256 tokenId, uint256 fullValue) internal {
        oracle.setValue(tokenId, fullValue);
        npm.mint(borrower, tokenId, token0, token1);
        vm.prank(borrower);
        vault.create(tokenId, borrower);
    }

    function _borrow(uint256 tokenId, uint256 amount) internal {
        vm.prank(borrower);
        vault.borrow(tokenId, amount);
    }

    function _fundLiquidator(uint256 amount) internal {
        asset.mint(liquidator, amount);
        vm.prank(liquidator);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @dev Calls liquidate with the ABI of whichever implementation is deployed.
    function _liquidate(uint256 tokenId, uint256 debtShares, address recipient, address sender) internal {
        vm.prank(sender);
        (bool ok,) = address(vault).call(
            abi.encodeWithSelector(
                OLD_LIQUIDATE_SELECTOR,
                LiquidateParamsOld(tokenId, debtShares, uint256(0), uint256(0), recipient, bytes(""))
            )
        );
        if (!ok) {
            vm.prank(sender);
            (ok,) = address(vault).call(
                abi.encodeWithSelector(
                    NEW_LIQUIDATE_SELECTOR,
                    LiquidateParamsNew(tokenId, uint256(0), uint256(0), recipient, bytes(""))
                )
            );
        }
        require(ok, "liquidate call failed");
    }
}

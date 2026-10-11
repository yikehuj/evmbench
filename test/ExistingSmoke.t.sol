// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OstiumRegistry} from "../src/OstiumRegistry.sol";
import {OstiumVerifier} from "../src/OstiumVerifier.sol";
import {OstiumPairsStorage} from "../src/OstiumPairsStorage.sol";
import {OstiumPairInfos} from "../src/OstiumPairInfos.sol";
import {OstiumOpenPnl} from "../src/OstiumOpenPnl.sol";
import {OstiumTradingStorage} from "../src/OstiumTradingStorage.sol";
import {OstiumTrading} from "../src/OstiumTrading.sol";
import {OstiumTradingCallbacks} from "../src/OstiumTradingCallbacks.sol";
import {OstiumPriceRouter} from "../src/OstiumPriceRouter.sol";
import {OstiumPrivatePriceUpKeep} from "../src/OstiumPrivatePriceUpKeep.sol";
import {OstiumVault} from "../src/OstiumVault.sol";
import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {IOstiumTrading} from "../src/interfaces/IOstiumTrading.sol";
import {IOstiumTradingStorage} from "../src/interfaces/IOstiumTradingStorage.sol";
import {IOstiumRegistry} from "../src/interfaces/IOstiumRegistry.sol";
import {IOstiumPairsStorage} from "../src/interfaces/IOstiumPairsStorage.sol";
import {IOstiumPairInfos} from "../src/interfaces/IOstiumPairInfos.sol";

/// Minimal cheatcode surface. Declared inline (the same pattern as the
/// official reference tests) so the repo builds offline without forge-std.
interface Vm {
    function prank(address caller) external;
    function startPrank(address caller) external;
    function stopPrank() external;
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
}

/// @notice Deployment smoke test: the full Ostium world must deploy behind
/// its proxies, seed the LP vault, and settle an HONEST market round trip --
/// open a 100x long, fill it with a CURRENT-dated signed report, close it,
/// fill the close with another current-dated report, and end with the
/// trader's balance restored. Runs unchanged on the vulnerable and patched
/// sources (current-dated reports pass both staleness and freshness guards).
contract ExistingSmoke {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 internal constant SIGNER_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address internal constant SIGNER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // vm.addr(SIGNER_KEY)

    bytes32 internal constant FEED_ID = 0x7404e3d104ea7841c3d9e6fd20adfe99b4ad586bc08d8f3bd3afef894cf184de;

    uint256 internal constant VAULT_SEED = 12_000_000e6;   // 12,000,000 USDC (6 dec)
    uint256 internal constant TRADER_SEED = 5_000_000e6;   // 5,000,000 USDC
    uint256 internal constant PRICE = 5_000 ether;         // 18-dec price
    uint256 internal constant E30 = 1e30;

    MockUSDC internal usdc;
    OstiumRegistry internal registry;
    OstiumVerifier internal verifier;
    address internal trading;
    address internal tradingStorage;
    address internal upkeep;
    address internal vault;

    address internal constant gov = 0x00000000000000000000000000000000000000B01;
    address internal constant dev = 0x00000000000000000000000000000000000000B02;
    address internal constant manager = 0x00000000000000000000000000000000000000B03;
    address internal constant owner = 0x00000000000000000000000000000000000000B04;

    function setUp() public {
        usdc = new MockUSDC(); // test contract holds the USDC owner role
        registry = new OstiumRegistry(gov, dev, manager, owner);
        verifier = new OstiumVerifier(IOstiumRegistry(address(registry)));

        IOstiumRegistry reg = IOstiumRegistry(address(registry));

        OstiumPairsStorage pairsImpl = new OstiumPairsStorage();
        OstiumPairInfos pairInfosImpl = new OstiumPairInfos();
        OstiumOpenPnl openPnlImpl = new OstiumOpenPnl();
        OstiumTradingStorage tradingStorageImpl = new OstiumTradingStorage();
        OstiumTrading tradingImpl = new OstiumTrading();
        OstiumTradingCallbacks callbacksImpl = new OstiumTradingCallbacks();
        OstiumPriceRouter routerImpl = new OstiumPriceRouter();
        OstiumPrivatePriceUpKeep upkeepImpl = new OstiumPrivatePriceUpKeep();
        OstiumVault vaultImpl = new OstiumVault();
        uint16[2] memory withdrawLockThresholds = [uint16(100), uint16(200)];

        address pairsStorage = address(new ERC1967Proxy(
            address(pairsImpl), abi.encodeCall(OstiumPairsStorage.initialize, (reg))
        ));
        address pairInfos = address(new ERC1967Proxy(
            address(pairInfosImpl), abi.encodeCall(OstiumPairInfos.initialize, (reg, manager, 1, 1))
        ));
        address openPnl = address(new ERC1967Proxy(
            address(openPnlImpl), abi.encodeCall(OstiumOpenPnl.initialize, (reg))
        ));
        tradingStorage = address(new ERC1967Proxy(
            address(tradingStorageImpl), abi.encodeCall(OstiumTradingStorage.initialize, (reg, address(usdc)))
        ));
        trading = address(new ERC1967Proxy(
            address(tradingImpl), abi.encodeCall(OstiumTrading.initialize, (reg, 1_000_000e6, 30, 30))
        ));
        address callbacks = address(new ERC1967Proxy(
            address(callbacksImpl), abi.encodeCall(OstiumTradingCallbacks.initialize, (reg))
        ));
        address router = address(new ERC1967Proxy(
            address(routerImpl), abi.encodeCall(OstiumPriceRouter.initialize, (reg, 900, 0))
        ));
        upkeep = address(new ERC1967Proxy(
            address(upkeepImpl), abi.encodeCall(OstiumPrivatePriceUpKeep.initialize, (reg))
        ));
        vault = address(new ERC1967Proxy(
            address(vaultImpl),
            abi.encodeCall(
                OstiumVault.initialize,
                (address(usdc), address(registry), E30, E30, 30000, 5000, 10001, withdrawLockThresholds)
            )
        ));

        vm.startPrank(gov);
        registry.registerContract("tradingStorage", tradingStorage);
        registry.registerContract("trading", trading);
        registry.registerContract("callbacks", callbacks);
        registry.registerContract("pairInfos", pairInfos);
        registry.registerContract("pairsStorage", pairsStorage);
        registry.registerContract("priceRouter", router);
        registry.registerContract("openPnl", openPnl);
        registry.registerContract("vault", vault);
        registry.registerContract("ostiumVerifier", address(verifier));
        registry.registerContract("PrivatePriceUpkeep", upkeep);
        vm.stopPrank();

        OstiumPrivatePriceUpKeep(upkeep).initializeV2(3600);
        OstiumVault(vault).initializeV2();
        OstiumVault(vault).initializeV3();
        OstiumVault(vault).initializeV4(manager);

        OstiumPairsStorage(pairsStorage).addGroup(
            IOstiumPairsStorage.Group({name: "crypto", maxLeverage: 10000, minLeverage: 100, maxCollateralP: 10000})
        );
        OstiumPairsStorage(pairsStorage).addFee(
            IOstiumPairsStorage.Fee({name: "fee", minLevPos: 1, oracleFee: 1, liqFeeP: 0})
        );
        OstiumPairsStorage(pairsStorage).addPair(
            IOstiumPairsStorage.Pair({
                from: "BTC",
                to: "USD",
                feed: FEED_ID,
                tradeSizeRef: 0,
                overnightMaxLeverage: 10000,
                maxLeverage: 0,
                groupIndex: 0,
                feeIndex: 0,
                oracle: "Private"
            })
        );

        OstiumPairInfos(pairInfos).setPairOpeningFees(
            0, IOstiumPairInfos.PairOpeningFees(0, 0, 0, 0, 10000, 0)
        );
        OstiumPairInfos(pairInfos).setPairFundingFees(
            0, IOstiumPairInfos.PairFundingFeesV2(0, 0, 0, 0, 0, 1e18, 0, 0, 0, 10000, 10000, 0)
        );

        vm.prank(manager);
        OstiumTradingStorage(tradingStorage).setMaxOpenInterest(0, 1e18);

        vm.prank(owner);
        OstiumPrivatePriceUpKeep(upkeep).registerForwarder(address(this));

        vm.prank(gov);
        verifier.registerAuthorizedSigner(SIGNER);

        // Seed the LP vault the only way the protocol allows.
        vm.startPrank(gov);
        usdc.mint(gov, VAULT_SEED);
        usdc.approve(vault, VAULT_SEED);
        OstiumVault(vault).requestDeposit(VAULT_SEED);
        OstiumVault(vault).forceSettlement();
        vm.stopPrank();

        // Fund the trader (the test contract).
        usdc.mint(address(this), TRADER_SEED);
        usdc.approve(tradingStorage, type(uint256).max);
    }

    /// @dev Signs a report exactly the way the off-band signer does:
    /// EIP-191 personal-message hash over keccak(reportData).
    function signReport(
        uint32 ts,
        int192 price
    ) internal view returns (bytes memory report) {
        bytes memory rd = abi.encode(FEED_ID, ts, price, price, price, true, false);
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(rd)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        return abi.encode(rd, r, s, v);
    }

    function testHonestMarketRoundTripStillWorks() public {
        IOstiumTradingStorage.Trade memory trade = IOstiumTradingStorage.Trade({
            collateral: 1_000e6,
            openPrice: uint192(PRICE),
            tp: 0,
            sl: 0,
            trader: address(this),
            leverage: 10000,
            pairIndex: 0,
            index: 0,
            buy: true,
            isDayTrade: false
        });
        IOstiumTrading(trading).openTrade(
            trade, IOstiumTradingStorage.BuilderFee({builder: address(0), builderFee: 0}), 0, 100
        );

        // Fill the open with a CURRENT-dated signed report (orderId 1).
        bytes memory openReport = signReport(uint32(block.timestamp), int192(PRICE));
        OstiumPrivatePriceUpKeep(upkeep).performUpkeep(abi.encode(openReport, 1));

        // Close the full position (orderId 2) and fill it at the same price.
        IOstiumTrading(trading).closeTradeMarket(0, 0, 10000, uint192(PRICE), 100);
        bytes memory closeReport = signReport(uint32(block.timestamp), int192(PRICE));
        OstiumPrivatePriceUpKeep(upkeep).performUpkeep(abi.encode(closeReport, 2));

        // Zero fees and zero price move: the trader's balance is restored.
        uint256 traderBal = usdc.balanceOf(address(this));
        require(
            traderBal >= TRADER_SEED - 1 && traderBal <= TRADER_SEED + 1,
            "trader not made whole"
        );
        require(usdc.totalSupply() == VAULT_SEED + TRADER_SEED, "USDC supply changed");
        require(usdc.balanceOf(vault) == VAULT_SEED, "vault balance changed");
    }
}

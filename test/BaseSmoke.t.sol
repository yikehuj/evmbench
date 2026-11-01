// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/DBR.sol";
import "../src/Oracle.sol";
import "../src/Market.sol";
import {SimpleERC20Escrow} from "../src/escrows/SimpleERC20Escrow.sol";
import {ERC20} from "./mocks/ERC20.sol";
import {EthFeed} from "./mocks/EthFeed.sol";

/// @notice Constructor-agnostic smoke test. Must pass on both the vulnerable
/// snapshot and the fixed snapshot, so it only touches interfaces that are
/// unchanged by any of the gold patches.
contract BaseSmokeTest is Test {
    function test_BaseSmoke_DeployDepositWithdraw() public {
        vm.warp(block.timestamp + 7 days);

        address gov = address(0xA);

        DolaBorrowingRights dbr = new DolaBorrowingRights(10000, "DOLA Borrowing Rights", "DBR", gov);
        Oracle oracle = new Oracle(gov);
        SimpleERC20Escrow escrowImplementation = new SimpleERC20Escrow();
        ERC20 collateral = new ERC20("Wrapped Ether", "WETH", 18);
        EthFeed feed = new EthFeed();

        vm.prank(gov);
        oracle.setFeed(address(collateral), IChainlinkFeed(address(feed)), 18);

        Market market = new Market(
            gov,
            address(this),
            address(0xB),
            address(escrowImplementation),
            IDolaBorrowingRights(address(dbr)),
            IERC20(address(collateral)),
            IOracle(address(oracle)),
            8500,
            500,
            100,
            false
        );

        collateral.mint(address(this), 1 ether);
        collateral.approve(address(market), 1 ether);

        market.deposit(1 ether);
        assertEq(collateral.balanceOf(address(market.predictEscrow(address(this)))), 1 ether, "escrow not funded");
        assertEq(market.getCollateralValue(address(this)), 1600 ether, "unexpected collateral value");

        market.withdraw(1 ether);
        assertEq(collateral.balanceOf(address(this)), 1 ether, "withdraw failed");
        assertEq(market.getCollateralValue(address(this)), 0, "escrow not emptied");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";

import {SmokeToken, SmokeMarket, SmokeIncentivesModule} from "./Mocks.sol";

/// @notice Constructor-agnostic invariant smoke test for SiloVault. It exercises
/// deposit + share transfer only through interfaces untouched by the gold patch,
/// so it must pass on both the vulnerable snapshot and the fixed tree.
contract BaseSmokeTest is Test {
    SmokeToken internal token;
    SmokeMarket internal market;
    SmokeIncentivesModule internal incentives;
    SiloVault internal vault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        token = new SmokeToken("Asset", "AST", 18);
        market = new SmokeMarket(token, type(uint256).max);
        incentives = new SmokeIncentivesModule();

        vault = new SiloVault(
            address(this),
            1 days,
            IVaultIncentivesModule(address(incentives)),
            address(token),
            "Silo Vault",
            "sV"
        );

        vault.submitCap(IERC4626(address(market)), 1e30);
        vm.warp(block.timestamp + 1 days + 1);
        vault.acceptCap(IERC4626(address(market)));

        IERC4626[] memory queue = new IERC4626[](1);
        queue[0] = IERC4626(address(market));
        vault.setSupplyQueue(queue);

        token.mint(alice, 1_000e18);
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
    }

    function test_Smoke_DepositAndTransfer() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000e18, alice);

        assertGt(shares, 0, "shares minted");
        assertEq(vault.balanceOf(alice), shares, "alice share balance");
        assertGt(market.balanceOf(address(vault)), 0, "market received assets");

        vm.prank(alice);
        vault.transfer(bob, shares / 2);

        assertEq(vault.balanceOf(bob), shares / 2, "bob received shares");
        assertEq(vault.totalSupply(), shares, "total supply unchanged by transfer");
    }
}

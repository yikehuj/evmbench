// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {TestERC20} from "../contracts/test/TestERC20.sol";
import {YVaultControllerMock} from "../contracts/test/YVaultControllerMock.sol";
import {YVault} from "../contracts/vaults/yVault/yVault.sol";

/// @notice Constructor-agnostic baseline smoke test for the yVault.
/// @dev Exercises the deposit/withdraw accounting that must keep working in
///      both the vulnerable and the gold-patched state.
contract BaseSmokeTest is Test {
    function test_yvault_deposit_withdraw_smoke() public {
        TestERC20 token = new TestERC20("Smoke Token", "SMOKE");
        YVaultControllerMock controller = new YVaultControllerMock();
        YVault vault = new YVault(
            address(token),
            address(controller),
            YVault.Rate({numerator: 1, denominator: 1})
        );

        address alice = makeAddr("alice");
        token.mint(alice, 100e18);

        vm.startPrank(alice);
        token.approve(address(vault), 100e18);
        vault.deposit(100e18);
        assertEq(vault.balanceOf(alice), 100e18);
        assertEq(vault.totalSupply(), 100e18);

        vault.withdraw(40e18);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 60e18);
        assertEq(token.balanceOf(alice), 40e18);
    }
}

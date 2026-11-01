// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Harness.sol";

contract BaseSmokeTest is Harness {
    function test_BaseSmoke() public {
        _setLimits(0, HUGE, HUGE, HUGE, HUGE);

        _deposit(1000_000000);

        _createLoan(1, 10000_000000);
        _borrow(1, 100_000000);

        asset.mint(borrower, 200_000000);
        vm.prank(borrower);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(borrower);
        vault.repay(1, 100_000000, false);

        vault.withdraw(100_000000, lender, lender);

        assertGt(vault.balanceOf(lender), 0);
        assertEq(vault.loans(1), 0);
    }
}

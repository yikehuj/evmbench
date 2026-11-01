// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import {FlashGovernanceArbiter} from "../contracts/DAO/FlashGovernanceArbiter.sol";
import {MockToken} from "../contracts/mocks/MockToken.sol";
import {MockDAO} from "../contracts/mocks/MockDAO.sol";

/// @notice Baseline smoke test. It exercises only the normal (non-slashed)
/// flash-governance lifecycle, which the H-04/M-03 fix does not change, so the
/// invariant suite passes both before and after the gold patch is applied.
contract BaseSmokeTest is Test {
    function test_flash_governance_deposit_and_withdraw() public {
        MockDAO dao = new MockDAO();
        MockToken token = new MockToken(address(this), address(this), 50e18);
        FlashGovernanceArbiter arbiter = new FlashGovernanceArbiter(address(dao));

        uint256 deposit = 10e18;
        uint256 lockDuration = 1 hours;

        arbiter.configureFlashGovernance(address(token), deposit, lockDuration, true);
        dao.setSuccessfulProposal(address(this), true);
        arbiter.endConfiguration();

        token.approve(address(arbiter), deposit);
        arbiter.assertGovernanceApproved(address(this), address(0xBEEF), true);

        assertEq(token.balanceOf(address(arbiter)), deposit, "deposit not escrowed");

        vm.warp(block.timestamp + lockDuration + 1);
        uint256 before = token.balanceOf(address(this));
        arbiter.withdrawGovernanceAsset(address(0xBEEF), address(token));

        assertEq(token.balanceOf(address(this)), before + deposit, "withdraw failed");
        assertEq(token.balanceOf(address(arbiter)), 0, "escrow not cleared");
    }
}

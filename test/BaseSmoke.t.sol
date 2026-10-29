// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import 'forge-std/Test.sol';

import {VoteEscrow} from '../contracts/vote-escrow/VoteEscrowDelegation.sol';
import {RewardDistributor} from '../contracts/rewards/RewardDistributor.sol';
import {ERC20Mock} from '../contracts/test/ERC20Mock.sol';

/// @notice Constructor-agnostic invariant smoke test.
/// @dev Deliberately avoids interfaces touched by the gold patches: it never
///      calls delegate/removeDelegation/transferFrom/addFee/merge, so it must
///      pass both on the vulnerable snapshot and on the fixed code.
contract BaseSmoke is Test {
    VoteEscrow internal ve;
    ERC20Mock internal token;
    RewardDistributor internal distributor;

    address internal constant ALICE = address(0xA11CE);

    function setUp() public {
        vm.warp(1_700_000_000);

        token = new ERC20Mock();
        ve = new VoteEscrow(address(token));
        distributor = new RewardDistributor(
            address(token),
            address(this),
            address(token),
            address(this)
        );

        token.transfer(ALICE, 1_000e18);
    }

    function test_Smoke_LockAndOwnership() public {
        vm.prank(ALICE);
        token.approve(address(ve), type(uint256).max);

        vm.prank(ALICE);
        uint256 id = ve.create_lock(1_000e18, 52 weeks);

        // Voting power is zero in the minting block; advance one block.
        vm.roll(block.number + 1);

        assertEq(ve.ownerOf(id), ALICE, 'owner mismatch');
        assertGt(ve.balanceOfNFT(id), 0, 'no voting power');
        assertEq(token.balanceOf(address(ve)), 1_000e18, 'escrow balance mismatch');
    }

    function test_Smoke_DistributorConfig() public {
        assertEq(distributor.trader(), address(this), 'trader mismatch');
        assertEq(distributor.startTime(), 1659211200, 'startTime mismatch');
    }
}

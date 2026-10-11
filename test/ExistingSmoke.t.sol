// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {DxLockLPDep} from "../src/DxLock_LP.sol";
import {MockLP} from "../src/mocks/MockLP.sol";

/// @notice Minimal cheatcode interface -- the repo pins solc 0.6.12, which
/// forge-std's current Vm interface does not support, so the tests declare
/// only the cheatcodes they need.
interface Vm {
    function deal(address account, uint256 newBalance) external;
}

/// @notice Deployment smoke test: the legacy locker must deploy, accept a
/// future-dated lock with its fee, and hold both the seeded custody balance
/// and the new deposit. Runs unchanged on vulnerable and patched sources; it
/// never unlocks, so the expiry path is not exercised here.
contract ExistingSmoke {
    Vm internal constant hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 internal constant LOCKER_CUSTODY = 1000 ether; // victim LP held in custody
    uint256 internal constant DEPOSIT = 1 ether;
    uint256 internal constant LOCK_FEE = 10000000000000000; // locker.lockFees

    MockLP internal lp;
    DxLockLPDep internal locker;

    function setUp() public {
        hevm.deal(address(this), 1 ether);
        lp = new MockLP();
        locker = new DxLockLPDep();
        lp.mint(address(locker), LOCKER_CUSTODY);
        lp.mint(address(this), DEPOSIT);
    }

    function testFixtureDeploysAndAcceptsALock() public {
        lp.approve(address(locker), DEPOSIT);
        locker.createLocker{value: LOCK_FEE}(address(lp), now + 3600, DEPOSIT, "smoke");

        (bool exists, bool locked,,,, ) = locker.DXLOCKERLP(address(this), 0);
        require(exists, "smoke: lock not recorded");
        require(locked, "smoke: lock must stay locked before expiry");
        require(locker.UserLockerCount(address(this)) == 1, "smoke: locker count");
        require(lp.balanceOf(address(locker)) == LOCKER_CUSTODY + DEPOSIT, "smoke: locker custody");
        require(lp.totalSupply() == LOCKER_CUSTODY + DEPOSIT, "smoke: LP supply");
        require(lp.balanceOf(address(this)) == 0, "smoke: deposit moved");
    }
}

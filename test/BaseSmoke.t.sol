// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {FIX_ONE, toFix, divuu} from "contracts/libraries/Fixed.sol";
import {DistributorP1} from "contracts/p1/Distributor.sol";
import {BackingManagerP1} from "contracts/p1/BackingManager.sol";
import {StRSRP1Votes} from "contracts/p1/StRSRVotes.sol";
import {Governance} from "contracts/plugins/governance/Governance.sol";

/// @notice Constructor-agnostic smoke test. Only touches the stable surface
/// (the Fixed library and compiled bytecode/interface markers), so it passes
/// both on the vulnerable base and after the gold patch.
contract BaseSmokeTest is Test {
    function testBaseSmoke() public {
        assertEq(uint256(FIX_ONE), 1e18, "FIX_ONE");
        assertEq(uint256(toFix(1)), 1e18, "toFix(1)");
        assertEq(uint256(divuu(1e18, 2)), uint256(5e35), "divuu");
    }

    function testContractsCompile() public {
        assertGt(type(DistributorP1).creationCode.length, 0, "DistributorP1");
        assertGt(type(BackingManagerP1).creationCode.length, 0, "BackingManagerP1");
        assertGt(type(StRSRP1Votes).creationCode.length, 0, "StRSRP1Votes");
        assertGt(type(Governance).creationCode.length, 0, "Governance");
    }
}

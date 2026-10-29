// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";

import {TokenDistributor} from "../contracts/distribution/TokenDistributor.sol";
import {IGlobals} from "../contracts/globals/IGlobals.sol";
import {ITokenDistributorParty} from "../contracts/distribution/ITokenDistributorParty.sol";

/// @notice Constructor-agnostic invariant smoke test.
/// Deploys the TokenDistributor with no external dependencies and checks the
/// untouched initial state. Passes on both the vulnerable and the fixed tree.
contract BaseSmokeTest is Test {
    function test_BaseSmoke() public {
        TokenDistributor distributor = new TokenDistributor(IGlobals(address(0)));
        assertEq(address(distributor.GLOBALS()), address(0));
        assertEq(distributor.emergencyActionsDisabled(), false);
        assertEq(distributor.lastDistributionIdPerParty(
            ITokenDistributorParty(address(0xdead))
        ), 0);
    }
}

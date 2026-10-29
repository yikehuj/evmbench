// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ArtGobblersTestBase} from "./utils/ArtGobblersTestBase.sol";

/// @notice Constructor-agnostic baseline smoke test. The H-01 patch only changes
/// the internals of mintLegendaryGobbler, so this test passes both before and
/// after the patch is applied.
contract BaseSmokeTest is ArtGobblersTestBase {
    function test_base_smoke() public {
        address user = users[0];

        // Mintlist claim (users[0] is the single leaf of the merkle tree).
        bytes32[] memory proof;
        vm.prank(user);
        gobblers.claimGobbler(proof);
        assertEq(gobblers.ownerOf(1), user);

        // Goo-funded mint.
        vm.startPrank(address(gobblers));
        goo.mintForGobblers(user, gobblers.gobblerPrice());
        vm.stopPrank();

        vm.prank(user);
        gobblers.mintFromGoo(type(uint256).max, false);
        assertEq(gobblers.ownerOf(2), user);
    }
}

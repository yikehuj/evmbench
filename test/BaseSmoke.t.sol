// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import {PaladinToken} from "../contracts/test/PaladinToken.sol";

/// @notice Minimal baseline smoke test. Kept constructor-agnostic (PaladinToken's
/// constructor is unchanged by the H-02 patch) so the invariant test suite has at
/// least one runnable test both before and after the patch is applied.
contract BaseSmokeTest is Test {
    function test_paladin_token_smoke() public {
        PaladinToken pal = new PaladinToken(1000e18, address(this), address(this));
        pal.setTransfersAllowed(true);

        address alice = makeAddr("alice");
        pal.transfer(alice, 100e18);

        assertEq(pal.balanceOf(alice), 100e18);
    }
}

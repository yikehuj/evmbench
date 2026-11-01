// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {TokenGGP} from "../contracts/contract/tokens/TokenGGP.sol";

/// @notice Minimal baseline smoke test. Kept constructor-agnostic (TokenGGP's
/// constructor is unchanged by every gold patch) so the invariant suite has at
/// least one runnable test in both the vulnerable and patched states.
contract BaseSmokeTest is Test {
	function test_ggp_token_smoke() public {
		TokenGGP ggp = new TokenGGP();
		address alice = makeAddr("alice");

		ggp.transfer(alice, 100e18);

		assertEq(ggp.balanceOf(alice), 100e18);
		assertEq(ggp.totalSupply(), 22_500_000e18);
	}
}

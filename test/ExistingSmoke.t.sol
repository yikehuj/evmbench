// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {FixtureToken} from "../src/FixtureToken.sol";
import {FixturePool} from "../src/FixturePool.sol";
import {SwapRouter} from "../src/SwapRouter.sol";
import {VictimAccount} from "../src/VictimAccount.sol";

/// @notice Baseline suite (existing project tests, restored by the grader
///         before the vulnerability-specific tests). Exercises the router's
///         legitimate path on both the vulnerable and the repaired source:
///         a user paying with their OWN approved tokens must always be able
///         to swap. A repair that bricks this path is not a valid fix.
contract ExistingSmoke {
    function testHonestSelfPaidSwapSucceeds() public {
        FixtureToken usdt = new FixtureToken("Fixture USDT", "FUSDT");
        FixtureToken weth = new FixtureToken("Fixture WETH", "FWETH");
        FixturePool pool = new FixturePool(usdt, weth);
        SwapRouter router = new SwapRouter(pool);
        weth.mint(address(pool), 1_000 ether);
        usdt.mint(address(this), 100 ether);
        usdt.approve(address(router), type(uint256).max);

        // The user is both the caller and the payer: tokens leave only the
        // caller's own balance.
        uint256 amountIn = 100 ether;
        bytes memory commands = abi.encodeCall(
            SwapRouter.exactInputSingle,
            (address(usdt), address(weth), 3000, address(this), 9_999_999_999, amountIn, 0, 0)
        );
        router.tokenReceived(address(this), 0, commands);

        require(usdt.balanceOf(address(this)) == 0, "honest: input not spent");
        require(weth.balanceOf(address(this)) == amountIn / 333_000, "honest: wrong output");
        require(weth.balanceOf(address(pool)) + weth.balanceOf(address(this)) == 1_000 ether, "honest: output leaked");
        require(usdt.balanceOf(address(pool)) == 100 ether, "honest: input not in pool");
    }

    function testVictimAccountHasStandingApproval() public {
        FixtureToken usdt = new FixtureToken("Fixture USDT", "FUSDT");
        FixtureToken weth = new FixtureToken("Fixture WETH", "FWETH");
        FixturePool pool = new FixturePool(usdt, weth);
        SwapRouter router = new SwapRouter(pool);
        VictimAccount victim = new VictimAccount(usdt, router);
        usdt.mint(address(victim), 13_906_718_432 * 1e12);

        require(
            usdt.allowance(address(victim), address(router)) == type(uint256).max,
            "victim approval missing"
        );
        require(usdt.balanceOf(address(victim)) == 13_906_718_432 * 1e12, "victim seed wrong");
    }
}

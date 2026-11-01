// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import {FixedToken} from "../contracts/Tokens/FixedToken.sol";
import {Crowdsale} from "../contracts/Auctions/Crowdsale.sol";

/// @notice Constructor-agnostic smoke test for the curated MISO snapshot.
/// @dev Deploys the auction token and a Crowdsale, and asserts only the
///      initialization surface. Deliberately avoids `_addCommitment` (the
///      function touched by the H-03 gold patch) so it compiles and passes on
///      both the vulnerable and the fixed source.
contract BaseSmokeTest is Test {
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    FixedToken internal token;
    Crowdsale internal crowdsale;

    function setUp() public {
        token = new FixedToken();
        token.initToken("MISO Inu", "MISO", address(this), 1_000_000e18);

        crowdsale = new Crowdsale();
        token.approve(address(crowdsale), 10_000e18);
        crowdsale.initCrowdsale(
            address(this),              // funder
            address(token),             // auction token
            ETH_ADDRESS,                // payment currency
            10_000e18,                  // total tokens
            block.timestamp + 100,      // start time
            block.timestamp + 10_000,   // end time
            1e18,                       // rate
            5_000e18,                   // goal
            address(this),              // admin
            address(0),                 // point list
            address(uint160(address(this))) // wallet
        );
    }

    function test_BaseSmoke() public {
        assertEq(uint256(token.decimals()), 18);
        assertEq(token.totalSupply(), 1_000_000e18);
        assertEq(crowdsale.tokenPrice(), 1e18);
        assertEq(crowdsale.auctionToken(), address(token));
        assertEq(crowdsale.paymentCurrency(), ETH_ADDRESS);
        assertFalse(crowdsale.finalized());
        assertFalse(crowdsale.auctionEnded());
        assertEq(token.balanceOf(address(crowdsale)), 10_000e18);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "forge-std/Test.sol";

import {MockERC20} from "../contracts/MockERC20.sol";
import {MockERC721} from "../contracts/MockERC721.sol";
import {InfinityExchange} from "../contracts/core/InfinityExchange.sol";
import {InfinityOrderBookComplication} from "../contracts/core/InfinityOrderBookComplication.sol";

/// @notice Constructor-agnostic smoke test for the curated Infinity snapshot.
/// @dev Deliberately avoids any interface touched by the H-05 gold patch
///      (takeMultipleOneOrders / IComplication.canExecTakeOneOrder), so it
///      compiles and passes on both the vulnerable and the fixed source.
contract BaseSmokeTest is Test {
    MockERC20 internal token;
    MockERC721 internal nft;
    InfinityExchange internal exchange;
    InfinityOrderBookComplication internal complication;

    function setUp() public {
        token = new MockERC20();
        nft = new MockERC721("Mock NFT", "MNFT");
        exchange = new InfinityExchange(address(token), address(this));
        complication = new InfinityOrderBookComplication();
        exchange.addCurrency(address(token));
        exchange.addComplication(address(complication));
    }

    function test_BaseSmoke() public {
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000 * 1e18);
        assertEq(nft.balanceOf(address(this)), 100);
        assertTrue(exchange.isValidCurrency(address(token)));
        assertTrue(exchange.isValidComplication(address(complication)));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

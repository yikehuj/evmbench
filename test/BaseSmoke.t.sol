// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Factory} from "../../src/Factory.sol";
import {PrivatePool} from "../../src/PrivatePool.sol";
import {MockNFT} from "./shared/Mocks.sol";

/// @notice Constructor-agnostic smoke test: deploys the factory, a private pool
/// implementation and creates one pool. It only uses interfaces that are stable
/// across the vulnerable snapshot and the gold patch, so it passes in both states.
contract BaseSmokeTest is Test {
    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function test_SmokeFactoryAndPool() public {
        Factory factory = new Factory();
        PrivatePool implementation = new PrivatePool(address(factory), address(0), address(0));
        factory.setPrivatePoolImplementation(address(implementation));

        MockNFT nft = new MockNFT();
        nft.mint(address(this), 1);
        nft.setApprovalForAll(address(factory), true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        PrivatePool pool = factory.create{value: 1 ether}(
            address(0),
            address(nft),
            100e18,
            10e18,
            0,
            100,
            bytes32(0),
            false,
            false,
            bytes32(0),
            tokenIds,
            1 ether
        );

        assertEq(pool.baseToken(), address(0));
        assertEq(pool.nft(), address(nft));
        assertEq(uint256(pool.virtualBaseTokenReserves()), 100e18);
        assertEq(uint256(pool.virtualNftReserves()), 10e18);
        assertEq(nft.ownerOf(1), address(pool));
        assertEq(address(pool).balance, 1 ether);

        (uint256 netInputAmount,,) = pool.buyQuote(1e18);
        assertGt(netInputAmount, 0);
    }
}

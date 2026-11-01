// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Factory} from "../../src/Factory.sol";
import {PrivatePool} from "../../src/PrivatePool.sol";
import {MockRoyaltyRegistry} from "./Mocks.sol";

/// @notice Shared fixture for the packaged exploit tests. Deploys a factory and a
/// private-pool implementation and offers helpers to create pools.
abstract contract CaviarTestBase is Test {
    Factory internal factory;
    PrivatePool internal implementation;
    MockRoyaltyRegistry internal royaltyRegistry;

    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _setUpFactory() internal {
        factory = new Factory();
        royaltyRegistry = new MockRoyaltyRegistry();
        implementation = new PrivatePool(address(factory), address(royaltyRegistry), address(0));
        factory.setPrivatePoolImplementation(address(implementation));
    }

    function _emptyProof() internal pure returns (PrivatePool.MerkleMultiProof memory) {
        return PrivatePool.MerkleMultiProof(new bytes32[](0), new bool[](0));
    }

    function _one(uint256 value) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = value;
    }

    function _createPool(
        address baseToken,
        address nft,
        uint128 virtualBaseTokenReserves,
        uint128 virtualNftReserves,
        uint56 changeFee,
        uint16 feeRate,
        bool payRoyalties,
        uint256[] memory tokenIds,
        uint256 baseTokenAmount
    ) internal returns (PrivatePool pool) {
        pool = factory.create{value: baseToken == address(0) ? baseTokenAmount : 0}(
            baseToken,
            nft,
            virtualBaseTokenReserves,
            virtualNftReserves,
            changeFee,
            feeRate,
            bytes32(0),
            false,
            payRoyalties,
            bytes32(0),
            tokenIds,
            baseTokenAmount
        );
    }
}

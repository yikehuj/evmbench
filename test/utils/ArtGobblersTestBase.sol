// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {Utilities} from "./Utilities.sol";

import {ArtGobblers} from "../../src/ArtGobblers.sol";
import {Goo} from "../../src/Goo.sol";
import {Pages} from "../../src/Pages.sol";
import {RandProvider} from "../../src/utils/rand/RandProvider.sol";

/// @notice Minimal randomness provider used by the tests. ArtGobblers only calls
/// `requestRandomBytes()` on it, and the test drives `acceptRandomSeed()` directly.
contract MockRandProvider is RandProvider {
    function requestRandomBytes() external returns (bytes32) {
        emit RandomBytesRequested(bytes32(0));
        return bytes32(0);
    }
}

/// @notice Shared deployment fixture for the ArtGobblers test suite.
/// Deploys Goo / Pages / ArtGobblers with a mock rand provider, mirroring the
/// original repo's setUp() but without Chainlink so the suite is fully offline.
abstract contract ArtGobblersTestBase is Test {
    Utilities internal utils;
    address payable[] internal users;

    ArtGobblers internal gobblers;
    Goo internal goo;
    Pages internal pages;
    MockRandProvider internal randProvider;

    function setUp() public virtual {
        utils = new Utilities();
        users = utils.createUsers(2);

        randProvider = new MockRandProvider();

        // ArtGobblers will be the 1st contract deployed after Goo, and Pages the 2nd.
        address gobblersAddr = utils.predictContractAddress(address(this), 1);
        address pagesAddr = utils.predictContractAddress(address(this), 2);

        goo = new Goo(gobblersAddr, pagesAddr);

        gobblers = new ArtGobblers(
            keccak256(abi.encodePacked(users[0])), // merkle root for users[0]
            block.timestamp, // mint start
            goo,
            Pages(pagesAddr),
            address(0xBEEF), // team
            address(0xDEAD), // community
            randProvider,
            "base",
            ""
        );

        pages = new Pages(block.timestamp, goo, address(0xBEEF), gobblers, "");
    }

    /// @notice Mint `num` gobblers to `addr`, paying from freshly minted goo.
    function mintGobblerToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; ++i) {
            vm.startPrank(address(gobblers));
            goo.mintForGobblers(addr, gobblers.gobblerPrice());
            vm.stopPrank();

            vm.prank(addr);
            gobblers.mintFromGoo(type(uint256).max, false);
        }
    }

    /// @notice Request a seed, fulfil it from the mock provider, then reveal.
    function setRandomnessAndReveal(uint256 numReveal, bytes32 seed) internal {
        gobblers.requestRandomSeed();
        vm.prank(address(randProvider));
        gobblers.acceptRandomSeed(bytes32(0), uint256(seed));
        gobblers.revealGobblers(numReveal);
    }
}

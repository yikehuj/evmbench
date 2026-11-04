// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Chainlink-style ETH/USD feed mock for exploit deployments.
/// @notice The price starts at 1600e18 and anyone may update it to simulate
///         market price moves (mirrors the audit test mock).
interface IChainlinkFeed {
    function decimals() external view returns (uint8);
    function latestAnswer() external view returns (uint);
}

contract EthFeedMock is IChainlinkFeed {
    uint8 decimals_ = 18;
    uint price_ = 1600e18;

    function decimals() external view returns (uint8) {
        return decimals_;
    }

    function latestAnswer() external view returns (uint) {
        return price_;
    }

    function changeAnswer(uint price) external {
        price_ = price;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

import {Scenario} from "./Scenario.sol";

/// @notice Read-only view of the deployed world, handed to the submission.
/// @dev Exposes only the addresses a participant legitimately needs: the DEX
///      plumbing, the three tokens and the three pools. It deliberately does not
///      expose the measurement, the harness or the reference solution.
contract World {
    Scenario public immutable scenario;

    constructor(address scenario_) {
        scenario = Scenario(payable(scenario_));
    }

    function wrap() external view returns (address) {
        return address(scenario.wrap());
    }

    function factory() external view returns (address) {
        return address(scenario.factory());
    }

    function router() external view returns (address) {
        return address(scenario.router());
    }

    function gov() external view returns (address) {
        return address(scenario.gov());
    }

    function rwd() external view returns (address) {
        return address(scenario.rwd());
    }

    function usd() external view returns (address) {
        return address(scenario.usd());
    }

    function govRwdPair() external view returns (address) {
        return scenario.govRwdPair();
    }

    function rwdUsdPair() external view returns (address) {
        return scenario.rwdUsdPair();
    }

    function usdWrapPair() external view returns (address) {
        return scenario.usdWrapPair();
    }
}

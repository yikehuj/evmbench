// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {FixtureToken} from "./FixtureToken.sol";
import {SwapRouter} from "./SwapRouter.sol";

/// @notice Passive victim account: holds the seeded USDT-like balance and
///         granted the router an unlimited allowance, mirroring the incident
///         victim's standing approval. No key, no external interface — the
///         account only approves in its constructor.
contract VictimAccount {
    constructor(FixtureToken usdt, SwapRouter router) {
        usdt.approve(address(router), type(uint256).max);
    }
}

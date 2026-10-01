// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SquidMulticall} from "./SquidMulticall.sol";
import {SeededToken} from "./SeededToken.sol";

contract Scenario {
    address public constant VICTIM = 0xaCc0c1f672B03B9a5fED4535f840f09B85f40E98;
    SquidMulticall public immutable multicall;
    SeededToken public immutable token;

    constructor() {
        multicall = new SquidMulticall();
        token = new SeededToken(VICTIM, address(multicall), 100 ether);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {FixtureToken} from "./FixtureToken.sol";

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

/// @notice Minimal UniswapV3-style pool fixture for the USDT/WETH pair.
///         Only the swap asset-flow is modeled: the pool calls the callback
///         on the swapper (the router) to pull the input token, then pays
///         the output token to the recipient at a fixed rate
///         (amountOut = amountIn / 333_000, approximating the incident's
///         13,906.72 USDT -> 0.04169 WETH exchange). AMM math, ticks and
///         LP mechanics are peripheral to the vulnerability and omitted.
contract FixturePool {
    FixtureToken public immutable token0; // USDT-like (input)
    FixtureToken public immutable token1; // WETH-like (output)
    uint256 public constant RATE_DIVISOR = 333_000;

    constructor(FixtureToken t0, FixtureToken t1) {
        token0 = t0;
        token1 = t1;
    }

    /// @notice Swapper must be the router: the pool calls back into it to
    ///         pull token0 before paying token1 out.
    function swap(address recipient, uint256 amountIn, bytes calldata data) external returns (uint256 amountOut) {
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(int256(amountIn), 0, data);
        amountOut = amountIn / RATE_DIVISOR;
        require(token1.balanceOf(address(this)) >= amountOut, "insufficient output liquidity");
        token1.transfer(recipient, amountOut);
    }
}

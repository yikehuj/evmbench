// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {FixturePool} from "./FixturePool.sol";
import {FixtureToken} from "./FixtureToken.sol";

/// @notice Reconstructed fixture of the custom (unverified) swap router
///         studied in the incident report: a router exposing UniswapV3-like
///         swap entry points plus an extra function `tokenReceived` that
///         takes an arbitrary `payer`, stores it, and executes caller-
///         supplied `commands` via DELEGATECALL to itself. The swap callback
///         then pulls the input token from the stored payer.
///         Storage slot numbers of the original decompilation are
///         represented by named storage variables (semantically equivalent).
contract SwapRouter {
    /// @notice payer for the in-flight swap (original: storage slot 6)
    address public payer;
    /// @notice caller of the in-flight swap (original: low 160 bits of slot 7)
    address public swapCaller;
    /// @notice per-payer per-caller nonce accounting (original: internal nonce mapping)
    mapping(address => mapping(address => uint256)) public swapNonces;

    event PayerRecorded(address indexed caller, address indexed payer, uint256 nonce);

    FixturePool public immutable pool;

    constructor(FixturePool p) {
        pool = p;
    }

    /// @notice Original selector 0x8943ec02, 4byte-dictionary name
    ///         `tokenReceived(address,uint256,bytes)`; functionally
    ///         `execute(address payer, uint256 nonce, bytes commands)`.
    ///         DELEGATECALLs into itself with the caller-supplied commands,
    ///         executing them in the router's own storage context.
    function tokenReceived(address payer_, uint256 nonce, bytes calldata commands) external {
        payer = payer_;
        swapCaller = msg.sender;
        swapNonces[payer_][msg.sender] += nonce;
        emit PayerRecorded(msg.sender, payer_, nonce);
        (bool ok, ) = address(this).delegatecall(commands);
        require(ok, "COMMANDS_FAILED");
    }

    /// @notice UniswapV3-style single-hop exact-input swap (original
    ///         selector 0x1a9d82d5). Executed via DELEGATECALL from
    ///         tokenReceived, so msg.sender is the original caller.
    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "DEADLINE");
        require(sqrtPriceLimitX96 == 0, "PRICE_LIMIT");
        amountOut = pool.swap(recipient, amountIn, abi.encode(tokenIn, tokenOut, fee));
        require(amountOut >= amountOutMinimum, "MIN_OUT");
    }

    /// @notice UniswapV3 swap callback (original selector 0xfa461e33).
    ///         Pulls the input token from the stored `payer` — the
    ///         vulnerability under study: nothing ties that payer to the
    ///         transaction's actual caller.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        require(msg.sender == address(pool), "CALLER_NOT_POOL");
        require(amount0Delta > 0 && amount1Delta == 0, "BAD_DELTA");
        (address tokenIn, address tokenOut, uint24 fee) = abi.decode(data, (address, address, uint24));
        // tokenIn/tokenOut/fee are recorded for parity with the callback
        // payload shape; only tokenIn is needed here.
        FixtureToken(tokenIn).transferFrom(payer, address(pool), uint256(amount0Delta));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPancakePair} from "../interfaces/IPancakePair.sol";

interface IERC20Like {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal PancakeSwap V2 router. Non-zero-code contract so LBP's
///         constructor sanity check (`_router.code.length != 0`) passes, and the
///         real `addLiquidity` path so `msg.sender == PANCAKE_ROUTER` grants the
///         LP-leg sell-tax exemption during liquidity seeding.
contract PancakeRouter {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function _pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = IPancakeFactoryLike(factory).getPair(token0, token1);
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 /*deadline*/
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(amountADesired >= amountAMin && amountBDesired >= amountBMin, "Router: INSUFFICIENT_AMOUNT");
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        address pair = _pairFor(tokenA, tokenB);
        require(pair != address(0), "Router: NO_PAIR");

        (uint256 amount0, uint256 amount1) =
            tokenA == token0 ? (amountADesired, amountBDesired) : (amountBDesired, amountADesired);

        IERC20Like(token0).transferFrom(msg.sender, pair, amount0);
        IERC20Like(token1).transferFrom(msg.sender, pair, amount1);
        liquidity = IPancakePair(pair).mint(to);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 /*amountAMin*/,
        uint256 /*amountBMin*/,
        address to,
        uint256 /*deadline*/
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = _pairFor(tokenA, tokenB);
        require(pair != address(0), "Router: NO_PAIR");
        IPancakePair(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = IPancakePair(pair).burn(to);
        (address token0, ) = _sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20Like(path[0]).transferFrom(msg.sender, _pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function _swap(uint256[] memory amounts, address[] memory path, address to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = _sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address pair = _pairFor(input, output);
            address recipient = i < path.length - 2 ? _pairFor(output, path[i + 2]) : to;
            IPancakePair(pair).swap(amount0Out, amount1Out, recipient, new bytes(0));
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Router: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "Router: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 9975;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Router: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getReserves(address tokenA, address tokenB)
        public
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, ) = _sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(_pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
}

interface IPancakeFactoryLike {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

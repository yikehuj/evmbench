// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

import {DexPair} from "./DexPair.sol";

interface IERC20Min {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice DexSwap V2 router. Single-hop and two-hop paths, which is all the
///         scenario uses.
contract DexRouter {
    address public immutable factory;
    address public immutable WETH;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "DexRouter: EXPIRED");
        _;
    }

    constructor(address factory_, address weth_) {
        factory = factory_;
        WETH = weth_;
    }

    receive() external payable {
        require(msg.sender == WETH, "DexRouter: ETH_ONLY_FROM_WETH");
    }

    function _pairFor(address tokenA, address tokenB) private view returns (address) {
        (bool ok, bytes memory ret) = factory.staticcall(
            abi.encodeWithSignature("getPair(address,address)", tokenA, tokenB)
        );
        require(ok, "DexRouter: FACTORY_CALL_FAILED");
        address pair = abi.decode(ret, (address));
        require(pair != address(0), "DexRouter: NO_PAIR");
        return pair;
    }

    function _sort(address a, address b) private pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }

    function _reserves(address tokenA, address tokenB) private view returns (uint256 rA, uint256 rB) {
        (address t0,) = _sort(tokenA, tokenB);
        (bool ok, bytes memory ret) =
            _pairFor(tokenA, tokenB).staticcall(abi.encodeWithSignature("getReserves()"));
        require(ok, "DexRouter: RESERVES_FAILED");
        (uint112 r0, uint112 r1,) = abi.decode(ret, (uint112, uint112, uint32));
        (rA, rB) = tokenA == t0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }

    function _amountOut(uint256 amountIn, uint256 rIn, uint256 rOut) private pure returns (uint256) {
        require(amountIn > 0 && rIn > 0 && rOut > 0, "DexRouter: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 9975;
        return (amountInWithFee * rOut) / (rIn * 10000 + amountInWithFee);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "DexRouter: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 rIn, uint256 rOut) = _reserves(path[i], path[i + 1]);
            amounts[i + 1] = _amountOut(amounts[i], rIn, rOut);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path.length == 2, "DexRouter: SINGLE_HOP_ONLY");
        (uint256 rIn, uint256 rOut) = _reserves(path[0], path[1]);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = _amountOut(amountIn, rIn, rOut);
        require(amounts[1] >= amountOutMin, "DexRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            IERC20Min(path[0]).transferFrom(msg.sender, _pairFor(path[0], path[1]), amountIn),
            "DexRouter: TRANSFER_FROM_FAILED"
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH && path.length == 2, "DexRouter: INVALID_PATH");
        (uint256 rIn, uint256 rOut) = _reserves(path[0], path[1]);
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = _amountOut(msg.value, rIn, rOut);
        require(amounts[1] >= amountOutMin, "DexRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        _depositWeth(msg.value);
        require(IERC20Min(WETH).transfer(_pairFor(path[0], path[1]), msg.value), "DexRouter: WETH_FAILED");
        _swap(amounts, path, to);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH && path.length == 2, "DexRouter: INVALID_PATH");
        (uint256 rIn, uint256 rOut) = _reserves(path[0], path[1]);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = _amountOut(amountIn, rIn, rOut);
        require(amounts[1] >= amountOutMin, "DexRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        require(
            IERC20Min(path[0]).transferFrom(msg.sender, _pairFor(path[0], path[1]), amountIn),
            "DexRouter: TRANSFER_FROM_FAILED"
        );
        _swap(amounts, path, address(this));
        _withdrawWeth(amounts[1]);
        (bool ok,) = payable(to).call{value: amounts[1]}("");
        require(ok, "DexRouter: ETH_FAILED");
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = _pairFor(tokenA, tokenB);
        if (DexPair(pair).totalSupply() == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            (uint256 rA, uint256 rB) = _reserves(tokenA, tokenB);
            uint256 bOptimal = (amountADesired * rB) / rA;
            if (bOptimal <= amountBDesired) {
                amountA = amountADesired;
                amountB = bOptimal;
            } else {
                amountA = (amountBDesired * rA) / rB;
                amountB = amountBDesired;
            }
        }
        require(amountA >= amountAMin && amountB >= amountBMin, "DexRouter: INSUFFICIENT_AMOUNT");
        require(IERC20Min(tokenA).transferFrom(msg.sender, pair, amountA), "DexRouter: A_FAILED");
        require(IERC20Min(tokenB).transferFrom(msg.sender, pair, amountB), "DexRouter: B_FAILED");
        liquidity = DexPair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        address pair = _pairFor(token, WETH);
        if (DexPair(pair).totalSupply() == 0) {
            amountToken = amountTokenDesired;
            amountETH = msg.value;
        } else {
            (uint256 rT, uint256 rW) = _reserves(token, WETH);
            uint256 wOptimal = (amountTokenDesired * rW) / rT;
            if (wOptimal <= msg.value) {
                amountToken = amountTokenDesired;
                amountETH = wOptimal;
            } else {
                amountToken = (msg.value * rT) / rW;
                amountETH = msg.value;
            }
        }
        require(amountToken >= amountTokenMin && amountETH >= amountETHMin, "DexRouter: INSUFFICIENT_AMOUNT");
        require(IERC20Min(token).transferFrom(msg.sender, pair, amountToken), "DexRouter: TOKEN_FAILED");
        _depositWeth(amountETH);
        require(IERC20Min(WETH).transfer(pair, amountETH), "DexRouter: WETH_FAILED");
        liquidity = DexPair(pair).mint(to);
        if (msg.value > amountETH) {
            (bool ok,) = payable(msg.sender).call{value: msg.value - amountETH}("");
            require(ok, "DexRouter: REFUND_FAILED");
        }
    }

    function _swap(uint256[] memory amounts, address[] memory path, address to) private {
        (address t0,) = _sort(path[0], path[1]);
        uint256 out = amounts[1];
        (uint256 amount0Out, uint256 amount1Out) = path[0] == t0 ? (uint256(0), out) : (out, uint256(0));
        DexPair(_pairFor(path[0], path[1])).swap(amount0Out, amount1Out, to, new bytes(0));
    }

    function _depositWeth(uint256 amount) private {
        (bool ok,) = WETH.call{value: amount}(abi.encodeWithSignature("deposit()"));
        require(ok, "DexRouter: DEPOSIT_FAILED");
    }

    function _withdrawWeth(uint256 amount) private {
        (bool ok,) = WETH.call(abi.encodeWithSignature("withdraw(uint256)", amount));
        require(ok, "DexRouter: WITHDRAW_FAILED");
    }
}

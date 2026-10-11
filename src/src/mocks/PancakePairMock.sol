// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IPancakeCallee {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

// Minimal reproduction of a PancakeSwap V2 pair's flash-swap entry point.
//
// `swap(amount0Out, amount1Out, to, data)` pays the requested tokens out,
// invokes `to.pancakeCall(...)` on the caller, then requires the borrowed
// amount plus a 0.25% fee to be paid back. It supplies flash liquidity only;
// it is not the vulnerable contract and behaves exactly like the real USDT/WBNB
// pair's flash leg (send out -> callback -> require repayment + fee).
contract PancakePairMock {
    address public immutable token0; // USDT
    address public immutable token1; // WBNB

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public constant FEE_NUMERATOR = 25;   // 0.25%
    uint256 public constant FEE_DENOMINATOR = 10000;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function sync() external {
        reserve0 = IERC20Min(token0).balanceOf(address(this));
        reserve1 = IERC20Min(token1).balanceOf(address(this));
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external {
        require(amount0Out > 0 || amount1Out > 0, "Pancake: INSUFFICIENT_OUTPUT_AMOUNT");
        require(to != address(this), "Pancake: INVALID_TO");

        if (amount0Out > 0) IERC20Min(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20Min(token1).transfer(to, amount1Out);
        if (data.length > 0) {
            IPancakeCallee(to).pancakeCall(msg.sender, amount0Out, amount1Out, data);
        }

        uint256 b0 = IERC20Min(token0).balanceOf(address(this));
        uint256 b1 = IERC20Min(token1).balanceOf(address(this));
        uint256 fee0 = (amount0Out * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 fee1 = (amount1Out * FEE_NUMERATOR) / FEE_DENOMINATOR;
        require(b0 >= reserve0 + fee0, "Pancake: K");
        require(b1 >= reserve1 + fee1, "Pancake: K");

        reserve0 = b0;
        reserve1 = b1;
    }
}

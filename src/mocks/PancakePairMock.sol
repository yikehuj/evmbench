// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IToken {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IPancakeCallee {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

// Minimal but faithful PancakeSwap V2 pair reproduction (0.25% fee). This mock
// is not the vulnerable contract: it is the LPD/USDC liquidity pair whose raw
// reserves the yield contract reads as a spot-price oracle. It implements the
// same constant-product swap semantics, `skim`/`sync`, and the exact
// `getReserves()`/`token0()` surface the Lpd.price() oracle consumes.
contract PancakePairMock {
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 private constant FEE_NUMERATOR = 25;    // 0.25%
    uint256 private constant FEE_DENOMINATOR = 10000;

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves()
        public
        view
        returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _update(uint256 balance0, uint256 balance1, uint112, uint112) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Pancake: OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2**32);
        emit Sync(reserve0, reserve1);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external {
        require(amount0Out > 0 || amount1Out > 0, "Pancake: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Pancake: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            IToken _token0 = IToken(token0);
            IToken _token1 = IToken(token1);
            if (amount0Out > 0) _token0.transfer(to, amount0Out);
            if (amount1Out > 0) _token1.transfer(to, amount1Out);
            if (data.length > 0) IPancakeCallee(to).pancakeCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = _token0.balanceOf(address(this));
            balance1 = _token1.balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "Pancake: INSUFFICIENT_INPUT_AMOUNT");
        {
            uint256 balance0Adjusted = balance0 * FEE_DENOMINATOR - amount0In * FEE_NUMERATOR;
            uint256 balance1Adjusted = balance1 * FEE_DENOMINATOR - amount1In * FEE_NUMERATOR;
            require(
                balance0Adjusted * balance1Adjusted >=
                    uint256(_reserve0) * uint256(_reserve1) * (FEE_DENOMINATOR ** 2),
                "Pancake: K"
            );
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external {
        IToken _token0 = IToken(token0);
        IToken _token1 = IToken(token1);
        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 excess0 = balance0 > reserve0 ? balance0 - reserve0 : 0;
        uint256 excess1 = balance1 > reserve1 ? balance1 - reserve1 : 0;
        if (excess0 > 0) _token0.transfer(to, excess0);
        if (excess1 > 0) _token1.transfer(to, excess1);
    }

    function sync() external {
        _update(
            IToken(token0).balanceOf(address(this)),
            IToken(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
}

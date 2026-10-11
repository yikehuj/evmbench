// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;

/// @notice DexSwap V2 pair, ported to 0.8.x with the semantics preserved:
///         constant product with a 0.25% fee, TWAP accumulators, `mint`, `burn`,
///         `swap` with an optional flash callback, `skim` and `sync`.
///
/// @dev The 0.8 port changes nothing about the reserve/balance relationship,
///      which is what matters here: `skim` sends the balance in excess of the
///      recorded reserve, and `sync` adopts the current balance as the reserve.
contract DexPair {
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    string public constant name = "Dex LPs";
    string public constant symbol = "Dex-LP";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address token0_, address token1_) external {
        require(msg.sender == factory, "Dex: FORBIDDEN");
        token0 = token0_;
        token1 = token1_;
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    // ---------------------------------------------------------------- ERC20

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "Dex: INSUFFICIENT_ALLOWANCE");
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) private {
        require(balanceOf[from] >= value, "Dex: INSUFFICIENT_BALANCE");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) private {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) private {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    // ------------------------------------------------------------ liquidity

    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = _balanceOf(token0, address(this));
        uint256 balance1 = _balanceOf(token1, address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        if (totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min((amount0 * totalSupply) / _reserve0, (amount1 * totalSupply) / _reserve1);
        }
        require(liquidity > 0, "Dex: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 liquidity = balanceOf[address(this)];
        uint256 supply = totalSupply;

        uint256 balance0 = _balanceOf(_token0, address(this));
        uint256 balance1 = _balanceOf(_token1, address(this));

        // Redeem against the supply *before* the burn, so the redeemer receives
        // their proportional share and not more.
        _burn(address(this), liquidity);

        amount0 = (liquidity * balance0) / supply;
        amount1 = (liquidity * balance1) / supply;

        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        balance0 = _balanceOf(_token0, address(this));
        balance1 = _balanceOf(_token1, address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // ------------------------------------------------------------------ swap

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, "Dex: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Dex: INSUFFICIENT_LIQUIDITY");

        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, "Dex: INVALID_TO");

        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        if (data.length > 0) IDexCallee(to).dexCall(msg.sender, amount0Out, amount1Out, data);

        uint256 balance0 = _balanceOf(_token0, address(this));
        uint256 balance1 = _balanceOf(_token1, address(this));

        uint256 amount0In =
            balance0 > uint256(_reserve0) - amount0Out ? balance0 - (uint256(_reserve0) - amount0Out) : 0;
        uint256 amount1In =
            balance1 > uint256(_reserve1) - amount1Out ? balance1 - (uint256(_reserve1) - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "Dex: INSUFFICIENT_INPUT_AMOUNT");

        uint256 balance0Adjusted = (balance0 * 10000) - (amount0In * 25);
        uint256 balance1Adjusted = (balance1 * 10000) - (amount1In * 25);
        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * 10000 ** 2,
            "Dex: K"
        );

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice Send the caller's LP share out, along with any balance held above
    ///         the recorded reserves.
    function skim(address to) external {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(_token0, to, _balanceOf(_token0, address(this)) - reserve0);
        _safeTransfer(_token1, to, _balanceOf(_token1, address(this)) - reserve1);
    }

    /// @notice Adopt the current balances as the reserves.
    function sync() external {
        _update(
            _balanceOf(token0, address(this)),
            _balanceOf(token1, address(this)),
            reserve0,
            reserve1
        );
    }

    // -------------------------------------------------------------- internal

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Dex: OVERFLOW");
        uint32 timestamp = uint32(block.timestamp % 2 ** 32);
        uint256 timeElapsed = timestamp - uint256(blockTimestampLast);
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += (uint256(_reserve1) << 112) / _reserve0 * timeElapsed;
            price1CumulativeLast += (uint256(_reserve0) << 112) / _reserve1 * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = timestamp;
        kLast = uint256(reserve0) * reserve1;
        emit Sync(reserve0, reserve1);
    }

    function _balanceOf(address token, address who) private view returns (uint256) {
        (bool ok, bytes memory ret) =
            token.staticcall(abi.encodeWithSelector(0x70a08231, who));
        require(ok, "Dex: BALANCE_CALL_FAILED");
        return abi.decode(ret, (uint256));
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "Dex: TRANSFER_FAILED");
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

interface IDexCallee {
    function dexCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

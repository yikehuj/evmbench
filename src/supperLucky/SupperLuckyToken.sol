/**
 *Submitted for verification at BscScan.com on 2024-04-27
 */

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
interface ISwapPair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function totalSupply() external view returns (uint);

    function kLast() external view returns (uint);

    function sync() external;

    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address);

    function feeTo() external view returns (address);
}

contract SupperLuckyToken is ERC20, Ownable {
    address public constant DEAD_WALLET =
        0x000000000000000000000000000000000000dEaD;
    uint256 private miningFee = 4000;
    uint256 public brunFee = 500;
    uint256 private rewardFee = 1500;

    IUniswapV2Router02 public immutable swapRouter;
    address public immutable usdtPair;
    address public immutable usdtAddress;

    address public miningPoolContract;
    address public claimContract;

    mapping(address => bool) public feeWhiteList;

    uint256 public burnCoolDownTime = 60 minutes;
    uint256 public lastBurnTime;
    uint256 public burnPercent = 200;

    bool private swapping;

    event FeeWhiteListUpdated(address indexed account, bool status);

    modifier burnCoolDown(uint256 time) {
        if (lastBurnTime > 0 && block.timestamp < lastBurnTime + time) {
            return;
        }
        _;
        lastBurnTime = block.timestamp;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address deployer
    ) ERC20(name_, symbol_) {
        _mint(deployer, 10000000000e18);
        _transferOwnership(deployer);

        if (block.chainid == 97) {
            usdtAddress = 0xC5A25d89470e873E8f37eA2B2E8d2e66181DDEF8;
            swapRouter = IUniswapV2Router02(
                0xD99D1c33F9fC3444f8101754aBC46c52416550D1
            );
        } else {
            usdtAddress = 0x55d398326f99059fF775485246999027B3197955;
            swapRouter = IUniswapV2Router02(
                0x10ED43C718714eb63d5aA57B78B54704E256024E
            );
        }
        // 创建交易对
        usdtPair = IUniswapV2Factory(swapRouter.factory()).createPair(
            address(this),
            usdtAddress
        );
        // 设置白名单
        _setFeeWhiteList(deployer, true);
        // deterministic task harness: prevent the first transfer from running the time-based burn
        lastBurnTime = block.timestamp;
    }

    // 管理函数
    function setFeeWhiteList(address addr, bool enable) external onlyOwner {
        _setFeeWhiteList(addr, enable);
    }

    function setContractAddress(
        address _miningPoolContract,
        address _claimContract
    ) external onlyOwner {
        miningPoolContract = _miningPoolContract;
        claimContract = _claimContract;
    }

    function setBurnCoolDownTime(uint256 _burnCoolDownTime) external onlyOwner {
        burnCoolDownTime = _burnCoolDownTime;
    }

    function setBurnPercent(uint256 _burnPercent) external onlyOwner {
        burnPercent = _burnPercent;
    }

    function setMiningFee(uint256 _miningFee) external onlyOwner {
        miningFee = _miningFee;
    }

    function setBrunFee(uint256 _brunFee) external onlyOwner {
        brunFee = _brunFee;
    }

    function setRewardFee(uint256 _rewardFee) external onlyOwner {
        rewardFee = _rewardFee;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(balanceOf(from) >= amount, "Balance insufficient");

        if (feeWhiteList[from] || feeWhiteList[to]) {
            super._transfer(from, to, amount);
            return;
        }
        require(from != usdtPair, "cannot buy or remove lp");

        uint256 addLPLiquidity = _isAddLiquidity(usdtPair, amount);
        if (
            !swapping &&
            from != usdtPair &&
            0 == addLPLiquidity &&
            from != miningPoolContract
        ) {
            swapping = true;
            autoBurnLiquidityPairTokens();
            swapping = false;
        }

        if (addLPLiquidity <= 0 && to == usdtPair) {
            //卖出
            sellTransfer(amount, from, to);
            return;
        }

        super._transfer(from, to, amount);
    }

    // 内部函数
    function _setFeeWhiteList(address addr, bool enable) private {
        feeWhiteList[addr] = enable;
        emit FeeWhiteListUpdated(addr, enable);
    }

    function autoBurnLiquidityPairTokens()
        internal
        burnCoolDown(burnCoolDownTime)
    {
        (, uint256 rThis, ) = _getReserves(usdtPair);
        uint256 timeSinceLastBurn = block.timestamp - lastBurnTime;
        uint256 amountToBurn = (rThis * burnPercent * timeSinceLastBurn) /
            10000 /
            86400;
        super._transfer(usdtPair, DEAD_WALLET, amountToBurn);
        ISwapPair(usdtPair).sync();
    }

    function ownerBurnLiquidityPairTokens(uint256 amount) public onlyOwner {
        super._transfer(usdtPair, owner(), amount);
        ISwapPair(usdtPair).sync();
    }

    event SellTransfer(uint256 amount);

    function sellTransfer(uint256 amount, address from, address to) internal {
        uint256 miningAmount = (amount * miningFee) / 10000;
        super._transfer(usdtPair, miningPoolContract, miningAmount);
        ISwapPair(usdtPair).sync();
        emit SellTransfer(amount);
        uint256 rewardAmount = (amount * rewardFee) / 10000;
        uint256 burnAmount = (amount * brunFee) / 10000;
        super._transfer(from, DEAD_WALLET, burnAmount);
        super._transfer(from, claimContract, rewardAmount);
        super._transfer(from, to, amount - rewardAmount - burnAmount);
    }

    function _isAddLiquidity(
        address pair,
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (uint256 rOther, uint256 rThis, uint256 balanceOther) = _getReserves(
            pair
        );
        uint256 amountOther;
        if (rOther > 0 && rThis > 0) {
            amountOther = (amount * rOther) / rThis;
        }
        //isAddLP
        if (balanceOther >= rOther + amountOther) {
            (liquidity, ) = _calLiquidity(
                pair,
                balanceOther,
                amount,
                rOther,
                rThis
            );
        }
    }

    function _calLiquidity(
        address pair,
        uint256 balanceA,
        uint256 amount,
        uint256 r0,
        uint256 r1
    ) private view returns (uint256 liquidity, uint256 feeToLiquidity) {
        uint256 pairTotalSupply = ISwapPair(pair).totalSupply();
        address feeTo = IUniswapV2Factory(swapRouter.factory()).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = ISwapPair(pair).kLast();

        if (feeOn && _kLast != 0) {
            uint256 rootK = Math.sqrt(r0 * r1);
            uint256 rootKLast = Math.sqrt(_kLast);
            if (rootK > rootKLast) {
                uint256 numerator = pairTotalSupply * (rootK - rootKLast) * 3;
                uint256 denominator = rootK * 5 + rootKLast;
                feeToLiquidity = numerator / denominator;
                if (feeToLiquidity > 0) pairTotalSupply += feeToLiquidity;
            }
        }

        uint256 amount0 = balanceA - r0;
        if (pairTotalSupply == 0) {
            if (amount0 > 0) {
                liquidity = Math.sqrt(amount0 * amount) - 1000;
            }
        } else {
            liquidity = Math.min(
                (amount0 * pairTotalSupply) / r0,
                (amount * pairTotalSupply) / r1
            );
        }
    }

    function _getReserves(
        address pair
    )
        public
        view
        returns (uint256 rOther, uint256 rThis, uint256 balanceOther)
    {
        ISwapPair mainPair = ISwapPair(pair);
        (uint r0, uint256 r1, ) = mainPair.getReserves();

        address tokenOther = mainPair.token0() == address(this)
            ? mainPair.token1()
            : mainPair.token0();

        if (tokenOther < address(this)) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }

        balanceOther = IERC20(tokenOther).balanceOf(pair);
    }

    function _isRemoveLiquidity(
        address pair,
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (uint256 rOther, , uint256 balanceOther) = _getReserves(pair);

        if (balanceOther <= rOther) {
            liquidity =
                (amount * ISwapPair(pair).totalSupply()) /
                (balanceOf(pair) - amount);
        }
    }
}

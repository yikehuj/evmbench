// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {LaunchTokenAuto} from "./LaunchTokenAuto.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IPositionManager {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory);
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;
    function nextTokenId() external view returns (uint256);
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

interface IWETH {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC20Min {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address a) external view returns (uint256);
}

// Same one-tx launch as LaunchpadFactory, but the token is LaunchTokenAuto and rewards are PUSHED
// to every holder in a single permissionless harvest() — no per-holder claim. The caller of harvest
// keeps a small keeper cut of the rewards to cover their gas, so anyone is incentivised to trigger it.
contract LaunchpadFactoryAuto {
    address public immutable implementation;
    address public owner; // protocol: receives 10% of all fees
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address public constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint24 public constant FEE = 10000;
    int24 public constant TICK_SPACING = 200;
    uint256 public constant PROTOCOL_BPS = 1000; // 10% to protocol
    uint256 public constant KEEPER_BPS = 100;    // 1% to whoever triggers harvest (gas comp)

    address[] public launches;
    mapping(address => address) public launcherOf;
    mapping(address => uint256) public positionIdOf;

    event Launched(address indexed token, address indexed launcher, address indexed pairedStock, string name, string symbol);
    event Harvested(address indexed token, address indexed keeper, uint256 toHolders, uint256 protocol, uint256 keeperCut, uint256 burnt);

    struct Params {
        string name;
        string symbol;
        uint256 supply;
        address pairedStock;
        uint256 seedAmount;
        bytes32 salt;
        string description;
        string image;
        string website;
        string twitter;
        bool holdersShare;
    }

    // The dev's initial buys, all paid by the dev in one launch tx. amounts[0]/recipients[0] is the
    // dev buy; up to 4 more seed the anti-snipe wallets. `totalPayIn` of `payAsset` is converted to
    // the paired asset (via preCommands when cross-asset), then split across the buys by `amounts`.
    struct SeedBuys {
        address payAsset;
        uint256 totalPayIn;
        bytes preCommands;
        bytes[] preInputs;
        uint128[] amounts;
        address[] recipients;
    }

    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    constructor() {
        owner = msg.sender;
        implementation = address(new LaunchTokenAuto());
    }

    function predict(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt, address(this));
    }

    function launch(
        Params calldata p,
        bytes calldata initCalldata,
        bytes calldata modifyCalldata,
        SeedBuys calldata sb
    ) external payable returns (address token) {
        token = Clones.cloneDeterministic(implementation, p.salt);
        LaunchTokenAuto(token).initialize(
            p.name, p.symbol, p.supply, address(this), p.pairedStock, p.description, p.image, p.website, p.twitter, p.holdersShare
        );

        LaunchTokenAuto(token).approve(PERMIT2, p.seedAmount);
        IPermit2(PERMIT2).approve(token, POSITION_MANAGER, uint160(p.seedAmount), type(uint48).max);

        positionIdOf[token] = IPositionManager(POSITION_MANAGER).nextTokenId();
        bytes[] memory calls = new bytes[](2);
        calls[0] = initCalldata;
        calls[1] = modifyCalldata;
        IPositionManager(POSITION_MANAGER).multicall(calls);

        if (sb.totalPayIn > 0) _seedBuys(token, p.pairedStock, sb);

        uint256 leftover = LaunchTokenAuto(token).balanceOf(address(this));
        if (leftover > 0) LaunchTokenAuto(token).transfer(msg.sender, leftover);

        uint256 dust = address(this).balance;
        if (dust > 0) {
            (bool ok, ) = msg.sender.call{value: dust}("");
            require(ok, "refund failed");
        }

        launches.push(token);
        launcherOf[token] = msg.sender;
        emit Launched(token, msg.sender, p.pairedStock, p.name, p.symbol);
    }

    // Permissionless: collect the pool fees, burn the launched-token side, then split the paired side
    // 10% protocol / 1% keeper (to whoever called this) / the rest PUSHED to every holder pro-rata.
    function harvest(address token) external {
        uint256 tokenId = positionIdOf[token];
        require(tokenId != 0, "unknown");
        address paired = LaunchTokenAuto(token).pairedStock();
        (address c0, address c1) = token < paired ? (token, paired) : (paired, token);

        uint256 pairedBefore = IERC20Min(paired).balanceOf(address(this));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, uint256(0), uint128(0), uint128(0), bytes("")); // DECREASE_LIQUIDITY (collect)
        params[1] = abi.encode(c0, c1, address(this));                                   // TAKE_PAIR to factory
        IPositionManager(POSITION_MANAGER).modifyLiquidities(abi.encode(hex"0111", params), block.timestamp + 300);

        uint256 tokFees = LaunchTokenAuto(token).balanceOf(address(this));
        if (tokFees > 0) LaunchTokenAuto(token).burn(tokFees);

        uint256 pairedFees = IERC20Min(paired).balanceOf(address(this)) - pairedBefore;
        if (pairedFees == 0) {
            emit Harvested(token, msg.sender, 0, 0, 0, tokFees);
            return;
        }

        uint256 protocolCut = (pairedFees * PROTOCOL_BPS) / 10000;
        uint256 keeperCut = (pairedFees * KEEPER_BPS) / 10000;
        uint256 userCut = pairedFees - protocolCut - keeperCut;
        if (protocolCut > 0) IERC20Min(paired).transfer(owner, protocolCut);
        if (keeperCut > 0) IERC20Min(paired).transfer(msg.sender, keeperCut);

        if (LaunchTokenAuto(token).holdersShare() && LaunchTokenAuto(token).holderCount() > 0) {
            IERC20Min(paired).transfer(token, userCut);
            LaunchTokenAuto(token).pushDistribute(userCut);
        } else {
            IERC20Min(paired).transfer(launcherOf[token], userCut);
        }
        emit Harvested(token, msg.sender, userCut, protocolCut, keeperCut, tokFees);
    }

    function _seedBuys(address token, address pairedStock, SeedBuys calldata sb) internal {
        uint256 n = sb.amounts.length;
        require(n == sb.recipients.length && n >= 1 && n <= 5, "buys"); // dev + up to 4 anti-snipe wallets

        // 1) acquire the total pay asset (dev pays for all of it)
        if (sb.payAsset == WETH) {
            require(msg.value >= sb.totalPayIn, "eth < payIn");
            IWETH(WETH).deposit{value: sb.totalPayIn}();
        } else {
            require(IERC20Min(sb.payAsset).transferFrom(msg.sender, address(this), sb.totalPayIn), "pull pay");
        }

        // 2) convert it all to the paired asset if the dev pays with something else
        if (sb.payAsset != pairedStock) {
            _approveRouter(sb.payAsset, sb.totalPayIn);
            IUniversalRouter(UNIVERSAL_ROUTER).execute(sb.preCommands, sb.preInputs, block.timestamp + 300);
        }

        // 3) split the paired across the buys, buy, and drop the tokens to each recipient
        uint256 totalPaired = IERC20Min(pairedStock).balanceOf(address(this));
        if (totalPaired == 0) return;
        uint256 sumAmounts;
        for (uint256 i; i < n; i++) sumAmounts += sb.amounts[i];
        require(sumAmounts > 0, "amounts");
        _approveRouter(pairedStock, totalPaired);

        uint256 allocated;
        for (uint256 i; i < n; i++) {
            uint256 share = i == n - 1 ? totalPaired - allocated : (totalPaired * sb.amounts[i]) / sumAmounts;
            allocated += share;
            if (share == 0) continue;
            uint256 balBefore = LaunchTokenAuto(token).balanceOf(address(this));
            _v4Buy(token, pairedStock, share);
            uint256 bought = LaunchTokenAuto(token).balanceOf(address(this)) - balBefore;
            if (bought > 0) LaunchTokenAuto(token).transfer(sb.recipients[i], bought);
        }

        uint256 stuck = IERC20Min(pairedStock).balanceOf(address(this));
        if (stuck > 0) IERC20Min(pairedStock).transfer(msg.sender, stuck);
    }

    function _approveRouter(address asset, uint256 amount) internal {
        IERC20Min(asset).approve(PERMIT2, amount);
        IPermit2(PERMIT2).approve(asset, UNIVERSAL_ROUTER, uint160(amount), type(uint48).max);
    }

    function _v4Buy(address token, address paired, uint256 amountIn) internal {
        (address c0, address c1) = paired < token ? (paired, token) : (token, paired);
        PoolKey memory key = PoolKey(c0, c1, FEE, TICK_SPACING, address(0));
        ExactInputSingleParams memory sp = ExactInputSingleParams(key, paired == c0, uint128(amountIn), 0, "");

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(sp);
        params[1] = abi.encode(paired, amountIn);
        params[2] = abi.encode(token, uint256(0));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(hex"060c0f", params);

        IUniversalRouter(UNIVERSAL_ROUTER).execute(hex"10", inputs, block.timestamp + 300);
    }

    function launchesCount() external view returns (uint256) {
        return launches.length;
    }

    function allLaunches() external view returns (address[] memory) {
        return launches;
    }

    receive() external payable {}
}

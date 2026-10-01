// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Vault4626} from "./Vault4626.sol";

/// @notice Small deterministic test facilities. They only provide tokens, pool
/// metadata and strategy custody; the vulnerable Vault4626 remains unchanged.
contract ScenarioToken {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    address public immutable minter;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
        minter = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "minter");
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "balance");
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "allowance");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ScenarioPool {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    constructor(address t0, address t1, uint24 f) {
        token0 = t0;
        token1 = t1;
        fee = f;
    }

    function slot0() external pure returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        return (79228162514264337593543950336, 0, 1, 1, 1, 0, true);
    }

    function observe(uint32[] calldata)
        external
        pure
        returns (int56[] memory ticks, uint160[] memory liquidity)
    {
        ticks = new int56[](2);
        liquidity = new uint160[](2);
    }
}

contract ScenarioStrategy {
    address public vault;
    address public token0;
    address public token1;
    uint128 public liquidity = 1;

    modifier onlyVault() {
        require(msg.sender == vault, "vault");
        _;
    }

    constructor(address t0, address t1) {
        token0 = t0;
        token1 = t1;
    }

    function setVault(address v) external { vault = v; }
    function setParams(address, uint24, int24, int24, uint16, uint32) external {}
    function currentLiquidity() external view returns (uint128) { return liquidity; }

    function getBalances() external view returns (uint256, uint256) {
        return (ScenarioToken(token0).balanceOf(address(this)), ScenarioToken(token1).balanceOf(address(this)));
    }

    function withdrawToVault(uint128 amount0, uint256, uint256)
        external
        onlyVault
        returns (uint256 out0, uint256 out1)
    {
        require(amount0 > 0 && liquidity > 0, "liquidity");
        liquidity = 0;
        out0 = ScenarioToken(token0).balanceOf(address(this));
        out1 = ScenarioToken(token1).balanceOf(address(this));
        if (out0 > 0) ScenarioToken(token0).transfer(vault, out0);
        if (out1 > 0) ScenarioToken(token1).transfer(vault, out1);
    }

    function collectFees() external pure returns (uint256, uint256) { return (0, 0); }
    function sweepIdleToVault() external onlyVault {
        uint256 a = ScenarioToken(token0).balanceOf(address(this));
        uint256 b = ScenarioToken(token1).balanceOf(address(this));
        if (a > 0) ScenarioToken(token0).transfer(vault, a);
        if (b > 0) ScenarioToken(token1).transfer(vault, b);
    }
    function sweepToken(address token, uint256 amount, address to) external onlyVault {
        ScenarioToken(token).transfer(to, amount);
    }
    function setLiquidity(uint128 l) external onlyVault { liquidity = l; }
    function mintPosition(uint256, uint256) external onlyVault returns (uint256) { liquidity = 1; return 1; }
    function rebalance(int24, int24, uint256, uint256) external onlyVault returns (uint256) { return liquidity; }
    function collectFeesAndReturn() external pure returns (uint256, uint256) { return (0, 0); }
    function emergencyWithdraw(address to) external onlyVault returns (uint256 a, uint256 b) {
        liquidity = 0;
        a = ScenarioToken(token0).balanceOf(address(this));
        b = ScenarioToken(token1).balanceOf(address(this));
        if (a > 0) ScenarioToken(token0).transfer(to, a);
        if (b > 0) ScenarioToken(token1).transfer(to, b);
    }
    function unpause() external onlyVault {}
    function addLiquidity() external onlyVault returns (uint128, uint256, uint256) { return (0, 0, 0); }
}

contract ScenarioRouter {}

contract Scenario {
    ScenarioToken public asset;
    ScenarioToken public weth;
    ScenarioPool public pool;
    ScenarioStrategy public strategy;
    ScenarioRouter public router;
    Vault4626 public vault;

    uint256 public constant INITIAL_ASSET = 100 ether;
    uint256 public constant VICTIM_WETH = 1000 ether;

    constructor() {}

    function initScenario(address vault_) external {
        require(msg.sender == tx.origin, "caller");
        require(address(asset) == address(0), "initialized");
        asset = new ScenarioToken("Scenario USD", "sUSD", 18);
        weth = new ScenarioToken("Scenario WETH", "sWETH", 18);
        pool = new ScenarioPool(address(asset), address(weth), 500);
        strategy = new ScenarioStrategy(address(asset), address(weth));
        router = new ScenarioRouter();
        vault = Vault4626(vault_);
    }

    function seed() external {
        require(msg.sender == tx.origin, "caller");
        asset.mint(msg.sender, INITIAL_ASSET);
        weth.mint(address(strategy), VICTIM_WETH);
    }

    function setupInit() external {
        require(msg.sender == tx.origin, "caller");
        vault.initialize(address(asset), address(this), address(router), 0, address(0));
    }

    function setupStrategy() external {
        require(msg.sender == tx.origin, "caller");
        strategy.setVault(address(vault));
        vault.setStrategy(address(strategy));
    }

    function setupParams() external {
        require(msg.sender == tx.origin, "caller");
        vault.setAllParams(address(pool), 500, -ticks(), ticks(), 10000, 0, 0, 0, 0, 0, address(0));
    }

    function ticks() internal pure returns (int24) { return 887000; }
}

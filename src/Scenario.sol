// Deterministic fixtures for the verified XLoot staking implementation.
pragma solidity ^0.8.20;

import "./Staking.sol";

contract LootMock {
    string public constant name = "Loot";
    string public constant symbol = "LOOT";
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) { allowance[msg.sender][spender] = amount; return true; }
    function transfer(address to, uint256 amount) external returns (bool) { require(balanceOf[msg.sender] >= amount); balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true; }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) { require(balanceOf[from] >= amount && allowance[from][msg.sender] >= amount); allowance[from][msg.sender] -= amount; balanceOf[from] -= amount; balanceOf[to] += amount; return true; }
}

contract XLootMock {
    mapping(uint256 => address) private owners;
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 id) external { require(owners[id] == address(0)); owners[id] = to; balanceOf[to]++; }
    function ownerOf(uint256 id) external view returns (address) { address o = owners[id]; require(o != address(0), "nonexistent"); return o; }
}

contract Scenario {
    LootMock public loot;
    XLootMock public xloot;
    Staking public staking;
    address public attacker;
    uint256 public constant STAKE = 1_000_000_000 ether;
    uint256 public constant REVENUE = 100 ether;

    constructor() payable {
        attacker = msg.sender;
        loot = new LootMock();
        xloot = new XLootMock();
        // IDs 0 and 1 ensure _updateXLoot discovers a nonzero supply. The
        // externally owned deployer owns ID 1 and can redeem it.
        xloot.mint(attacker, 0);
        xloot.mint(attacker, 1);
        staking = new Staking();
        staking.initialize(address(loot), address(xloot), block.timestamp - 1 days);
        loot.mint(attacker, STAKE + 1000 ether);
    }

    function seed() external { require(msg.sender == attacker, "only attacker"); }
    receive() external payable {}
}

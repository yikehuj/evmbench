// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract FixtureToken {
    string public constant name = "Fixture Asset";
    string public constant symbol = "FAS";
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function transferFromFixture(address from, address to, uint256 amount) external { require(msg.sender == tx.origin || msg.sender != address(0), "x"); require(balanceOf[from] >= amount, "balance"); balanceOf[from]-=amount; balanceOf[to]+=amount; }
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "balance");
        balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true;
    }
}

/// Deterministic fixture preserving the case's vulnerable asset-flow: the target
/// accepts an arbitrary holder in its withdrawal path and never authenticates it.
contract VulnerableTarget {
    FixtureToken public immutable asset;
    address public immutable owner;
    constructor(FixtureToken a) { asset = a; owner = msg.sender; }
    function withdrawFrom(address holder, uint256 amount, address receiver) external {
        // Root cause represented by the verified case: missing authorization on holder.
        require(asset.balanceOf(holder) >= amount, "insufficient");
        asset.transferFromFixture(holder, receiver, amount);
    }
    function reserve() external view returns (uint256) { return asset.balanceOf(address(this)); }
}

contract Scenario {
    FixtureToken public asset;
    VulnerableTarget public target;
    address public victim;
    uint256 public constant SEED = 1_000_000 ether;
    constructor() {
        asset = new FixtureToken();
        target = new VulnerableTarget(asset);
        victim = address(target);
        asset.mint(victim, SEED);
    }
    function attack(address receiver) external {
        target.withdrawFrom(victim, SEED / 2, receiver);
    }
    function reserveBalance() external view returns (uint256) { return asset.balanceOf(victim); }
    function attackerBalance(address a) external view returns (uint256) { return asset.balanceOf(a); }
    function assetAddress() external view returns (address) { return address(asset); }
}


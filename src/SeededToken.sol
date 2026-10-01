// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice Closed-sandbox ERC20 used only to seed the pre-existing victim state.
/// It has no mint or faucet entry point after construction.
contract SeededToken {
    string public constant name = "Seeded BNB ETH";
    string public constant symbol = "sETH";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    constructor(address holder, address spender, uint256 amount) {
        totalSupply = amount;
        balances[holder] = amount;
        allowances[holder][spender] = type(uint256).max;
        emit Transfer(address(0), holder, amount);
        emit Approval(holder, spender, type(uint256).max);
    }

    function balanceOf(address account) external view returns (uint256) { return balances[account]; }
    function allowance(address owner, address spender) external view returns (uint256) { return allowances[owner][spender]; }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 current = allowances[from][msg.sender];
        require(current >= amount, "allowance");
        if (current != type(uint256).max) {
            allowances[from][msg.sender] = current - amount;
            emit Approval(from, msg.sender, current - amount);
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        require(balances[from] >= amount, "balance");
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

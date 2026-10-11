// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Glove (GLO) — the reward token minted by WUSD's `_englove` reward path.
//
// Faithful minimal reproduction of the real Glove at
// 0x70c5f366dB60A2a0C59C4C24754803Ee47Ed7284, stripped to the attack-dependent
// surface: a single "creditor" (the WUSD wrapper) may mint reward GLO to any
// account via `mintCreditless`. The real contract's credit/creditless/creditize
// machinery only governs whether held reward GLO is burned on unwrap; it does
// not affect this vulnerability (the attacker moves the reward GLO out before
// unwrapping), so it is dropped here.
contract Glove {
    string public constant name = "Glove";
    string public constant symbol = "GLO";
    uint8 public constant decimals = 18;

    address public creditor;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        creditor = msg.sender;
    }

    /// @notice The current creditor may hand the minting role to the wrapper.
    function setCreditor(address c) external {
        require(msg.sender == creditor, "GLO: !creditor");
        creditor = c;
    }

    function mintCreditless(address account, uint256 amount) external {
        require(msg.sender == creditor, "GLO: !creditor");
        _mint(account, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "GLO: mint to 0 addr");
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "GLO: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "GLO: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

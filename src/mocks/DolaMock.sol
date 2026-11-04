// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Mock DOLA token used by exploit deployments.
/// @notice The FiRM Market hard-codes mainnet DOLA at
///         0x865377367054516e17014CcdED1e7d814EDC9ce4, so deployment scripts
///         place this mock's runtime code at that address with anvil_setCode
///         and write the ephemeral deployer into the operator slot (slot 0).
///         Only the operator may mint.
contract DolaMock {
    address public operator;                                   // slot 0
    uint256 public totalSupply;                                // slot 1
    mapping(address => uint256) public balanceOf;              // slot 2
    mapping(address => mapping(address => uint256)) public allowance; // slot 3

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        operator = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == operator, "ONLY OPERATOR");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "insufficient allowance");
        allowance[from][msg.sender] = allowed - amount;
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

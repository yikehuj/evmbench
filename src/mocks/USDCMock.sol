// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// USDC Mock for CompoundProvider allowance sweep exploit
// Real USDC is a proxy with blacklisting/owner features.
// The exploit only requires plain ERC20 semantics with pre-granted allowances.

contract USDCMock {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // Mint initial supply to a treasury address for victim distribution
        // The deploy script uses set_storage to seed victims directly
        uint256 supply = 1_000_000_000 * 10**6; // 1 billion USDC
        address treasury = 0x1111111111111111111111111111111111111111;
        _balances[treasury] = supply;
        totalSupply = supply;
        emit Transfer(address(0), treasury, supply);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "USDC: transfer amount exceeds allowance");
        unchecked {
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    // OpenZeppelin SafeERC20-compatible wrappers. The provider calls these
    // selectors directly; they delegate to the standard ERC20 entry points.
    function safeTransferFrom(address from, address to, uint256 amount) external returns (bool) {
        return transferFrom(from, to, amount);
    }

    function safeTransfer(address to, uint256 amount) external returns (bool) {
        return transfer(to, amount);
    }

    // Restricted mint used by the deployment fixture to seed accounts
    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "USDC: transfer from the zero address");
        require(to != address(0), "USDC: transfer to the zero address");
        uint256 balance = _balances[from];
        require(balance >= amount, "USDC: transfer amount exceeds balance");
        unchecked {
            _balances[from] = balance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "USDC: approve from the zero address");
        require(spender != address(0), "USDC: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

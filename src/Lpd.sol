// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPancakePair {
    function getReserves() external view returns (uint112, uint112, uint32);
}

// Lpd — the "LOOPSDAO" ERC-20 token whose `price()` is used by LpdFi as the
// accounting oracle (real token 0x38763eebe58a69c9cc91876947d9fb83e1273604).
//
// The vulnerable behaviour is `price()`: it returns the LPD/USDC pair's raw
// instantaneous reserve ratio with no TWAP, delay, liquidity sanity check, or
// deviation guard. LpdFi.buy() divides a caller-selected nominal USDC amount by
// this spot price to decide how much LPD collateral to take, then stores the
// caller-selected amount as the interest principal -- so a same-transaction
// reserve move lets the attacker book an arbitrarily large principal for almost
// no collateral.
//
// `referencePrice`/`setReferencePrice` are present in both builds; only the
// patched build's `price()` consults them. The token-side fee-on-transfer seen
// on-chain is dropped (incidental to the vulnerability).

contract Lpd {
    string public name = "LOOPSDAO";
    string public symbol = "LPD";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public pair; // LPD/USDC pair (LPD = token0, USDC = token1)
    uint256 public referencePrice; // patched build only; unused here
    uint256 public constant MAX_PRICE_DEVIATION_BPS = 500; // 5%

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setPair(address _pair) external onlyOwner {
        pair = _pair;
    }

    function setReferencePrice(uint256 _p) external onlyOwner {
        require(referencePrice == 0, "already set");
        referencePrice = _p;
    }

    // USDC per LPD, scaled by 1e18, from the pair's instantaneous reserves.
    // VULNERABILITY: raw spot read, no manipulation resistance.
    function price() public view returns (uint256) {
        (uint112 r0, uint112 r1, ) = IPancakePair(pair).getReserves();
        return (uint256(r1) * 1e18) / uint256(r0);
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
            require(allowed >= amount, "insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

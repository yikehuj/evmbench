// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// Minimal 6-decimal ERC20 stand-in for Arbitrum USDC (0xaf88d065e77c8cc2239327c5edb3a432268e5831).
// Mint is owner-gated so the seeded world can fund counterparties; the grading
// guardrail (asset totalSupply unchanged) still catches any forged supply.
contract MockUSDC is ERC20, Ownable {
    constructor() ERC20('USD Coin', 'USDC') Ownable(msg.sender) {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

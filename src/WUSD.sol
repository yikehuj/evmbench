// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IGlove} from "./interfaces/IGlove.sol";

// WUSD — faithful minimal reproduction of the vulnerable wrapper at
// 0x068e3563b1c19590f822c0e13445c4fa1b9eefa5, stripped to the attack-dependent
// surface. `wrap` mints 1:1 WUSD for a whitelisted fiatcoin and rewards the
// caller with GLO via `_englove`; `unwrap` burns WUSD and returns the fiatcoin.
//
// VULNERABILITY: `_englove` grants the GLO reward whenever the caller's CURRENT
// GLO balance is below `_MAX_GLOVE`. Eligibility is keyed to a live balance
// rather than a durable one-time record, so a caller can move the reward GLO to
// another address (resetting its own balance) and claim the full introductory
// reward again on the next wrap — re-arming the per-address cap indefinitely.
//
// Simplifications vs. the on-chain implementation (none touch the vulnerability):
//   - the 1% wrap fee / fee-collector / Uniswap swap of the real `_parse` are
//     dropped, so wrap/unwrap is capital-neutral; the fee is a cost knob, not
//     part of the reward-gate flaw;
//   - `_snap` / `_epoch` / `_deglove` (the epoch + GLO-credit burn bookkeeping)
//     are dropped; they only govern whether HELD reward GLO is burned on
//     unwrap, which this exploit sidesteps by moving the GLO out first;
//   - permit/EIP-2612 and the referrer/frontender hooks are dropped.

contract WUSD {
    // Reward-gate parameters (faithful to the real constants).
    uint256 public constant MIN_GLOVABLE = 100e18;
    uint256 public constant MID_GLOVE = 0.01e18;
    uint256 public constant MAX_GLOVE = 2e18;
    uint256 public constant EPOCH = 100_000e18;

    address public immutable glove;

    mapping(address => bool) public isFiatcoin;
    mapping(address => uint8) public fiatDecimals;

    string public constant name = "Wrapped USD";
    string public constant symbol = "WUSD";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Wrap(address indexed account, address fiatcoin, uint256 amount, address referrer);
    event Unwrap(address indexed account, address fiatcoin, uint256 amount);

    constructor(address _glove, address _fiatcoin, uint8 _decimals) {
        glove = _glove;
        isFiatcoin[_fiatcoin] = true;
        fiatDecimals[_fiatcoin] = _decimals;
    }

    function _normalize(uint256 amount, uint8 dec) internal pure returns (uint256) {
        return amount * 1e18 / (10 ** dec);
    }

    function _denormalize(uint256 amount, uint8 dec) internal pure returns (uint256) {
        return amount * (10 ** dec) / 1e18;
    }

    function _mint(address account, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(balanceOf[account] >= amount, "WUSD: burn > balance");
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    /// @notice Reward the caller with GLO for wrapping. The gate reads the
    /// caller's live GLO balance only — see the VULNERABILITY note above.
    function _englove(uint256 wrapping) internal {
        uint256 gloves = IGlove(glove).balanceOf(msg.sender);
        if (wrapping >= MIN_GLOVABLE && gloves < MAX_GLOVE) {
            uint256 reward = wrapping > 1_000e18
                ? (MAX_GLOVE * wrapping) / EPOCH
                : (MID_GLOVE * wrapping) / 1_000e18;
            uint256 amount = reward > (MAX_GLOVE - gloves) ? (MAX_GLOVE - gloves) : reward;
            IGlove(glove).mintCreditless(msg.sender, amount);
        }
    }

    function wrap(address fiatcoin, uint256 amount, address referrer) external {
        require(isFiatcoin[fiatcoin], "WUSD: !fiatcoin");
        require(amount > 0, "WUSD: wrap(0)");
        uint256 wrapping = _normalize(amount, fiatDecimals[fiatcoin]);
        _mint(msg.sender, wrapping);
        _englove(wrapping);
        require(IERC20(fiatcoin).transferFrom(msg.sender, address(this), amount), "WUSD: pull");
        emit Wrap(msg.sender, fiatcoin, amount, referrer);
    }

    function unwrap(address fiatcoin, uint256 amount) external {
        require(isFiatcoin[fiatcoin], "WUSD: !fiatcoin");
        require(amount > 0, "WUSD: unwrap(0)");
        uint256 unwrapping = _denormalize(amount, fiatDecimals[fiatcoin]);
        require(IERC20(fiatcoin).balanceOf(address(this)) >= unwrapping, "WUSD: !enough fiatcoin");
        _burn(msg.sender, amount);
        require(IERC20(fiatcoin).transfer(msg.sender, unwrapping), "WUSD: pay");
        emit Unwrap(msg.sender, fiatcoin, amount);
    }
}

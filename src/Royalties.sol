// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Royal1155LDA} from "./Royal1155LDA.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// Royalties — minimal faithful reproduction of the royalty payout pool (real
// impl 0x1e0598614d9168a657cb57bd038dfd71812c9074). It pools USDC from every
// LDA tier and pays each holder a pro-rata share of the pooled credit.
//
// The vulnerability is inherited: `claim` derives a holder's ownership share
// from `LDA.tierBalanceOf(tierId, holder)` — the very same custom tier count
// that `Royal1155LDA._beforeTokenTransfer` inflates on zero-amount batch
// transfers. There is no cross-check against the canonical ERC-1155 balance,
// so a holder whose tier count is inflated (e.g. 100 with a supply of 1) can
// claim 100x the pool's pro-rata share of their own deposit — pulling the
// difference out of other tiers' pooled funds.
//
// Simplified claim model: `claimable = tierCredit[tierId] * ldaBalance /
// tierSupply[tierId] - claimed[tierId][holder]`. This matches the real
// `_settleUcr` pro-rata formula (`tcr * ldaBalance / ldaSupply`) while dropping
// the settlement-epoch bookkeeping, which does not affect the vulnerability.

contract Royalties {
    Royal1155LDA public immutable LDA;
    MockERC20 public immutable USDC;

    // tierId -> reclaimer (holder entitled to trigger settlement; metadata only)
    mapping(uint128 => address) public tierClaimers;
    // tierId -> cached total supply of the tier's LDA (from LDA.getTierTotalSupply)
    mapping(uint128 => uint256) public tierSupply;
    // tierId -> total USDC credited to the tier by holders
    mapping(uint128 => uint256) public tierCredit;
    // tierId -> holder -> USDC already claimed
    mapping(uint128 => mapping(address => uint256)) public claimed;

    address public owner;

    event Initialized(uint128 indexed tierId, address indexed reclaimer, uint256 supply);
    event Deposited(uint128 indexed tierId, address indexed from, uint256 amount);
    event Claimed(uint128 indexed tierId, address indexed holder, address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(Royal1155LDA _lda, MockERC20 _usdc) {
        LDA = _lda;
        USDC = _usdc;
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    /// @notice Register a tier and cache its LDA supply. Owner-only; called once
    /// per tier during seeding.
    function initializeTier(uint128 tierId, address reclaimer) external onlyOwner {
        require(tierSupply[tierId] == 0, "already initialized");
        require(reclaimer != address(0), "zero reclaimer");
        uint256 supply = LDA.getTierTotalSupply(tierId);
        require(supply != 0, "unknown tier");
        tierClaimers[tierId] = reclaimer;
        tierSupply[tierId] = supply;
        emit Initialized(tierId, reclaimer, supply);
    }

    /// @notice A tier-LDA holder deposits USDC credited to the tier's pool.
    function deposit(uint128 tierId, uint256 amount) external {
        require(tierSupply[tierId] != 0, "tier not initialized");
        require(amount != 0, "zero amount");
        require(LDA.tierBalanceOf(tierId, msg.sender) != 0, "not a holder");
        tierCredit[tierId] += amount;
        USDC.transferFrom(msg.sender, address(this), amount);
        emit Deposited(tierId, msg.sender, amount);
    }

    /// @notice Claim the pro-rata share of the tier's pooled credit. The holder's
    /// ownership share comes from the (inflatable) tier balance, not the
    /// canonical ERC-1155 balance.
    function claim(uint128 tierId, address recipient) external {
        uint256 ldaBalance = LDA.tierBalanceOf(tierId, msg.sender);
        require(ldaBalance != 0, "not a holder");
        uint256 supply = tierSupply[tierId];
        uint256 credit = tierCredit[tierId];
        uint256 claimable = (credit * ldaBalance) / supply;
        uint256 alreadyClaimed = claimed[tierId][msg.sender];
        require(claimable > alreadyClaimed, "nothing to claim");
        uint256 payout = claimable - alreadyClaimed;
        claimed[tierId][msg.sender] = claimable;
        USDC.transfer(recipient, payout);
        emit Claimed(tierId, msg.sender, recipient, payout);
    }
}

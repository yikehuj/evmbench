// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./mocks/MockERC20.sol";

// MokeLPDividend — minimal faithful reproduction of the vulnerable dividend
// contract (real 0x5ae569d8a0539a6a603e96a26ac8caea7ceba377, non-proxy).
//
// Vulnerability: `_syncUserLP` credits a user's STALE recorded LP balance for
// every newly-accrued dividend before replacing the record with the current
// balance. An account whose current LP balance is zero therefore still earns
// the full distribution on its retired record — stale liabilities equivalent to
// the whole LP supply can consume the entire dividend pool alongside live LP
// ownership.
//
// Simplifications vs. the on-chain implementation (none touch the vulnerability):
//   - the dividend asset is USDC (ERC20) instead of native BNB, and the MOKE
//     swap (`swapExactTokensForETHSupportingFeeOnTransferTokens`) is dropped in
//     favour of a direct `depositDividend` — the per-LP distribution accounting
//     is otherwise identical;
//   - the LP token is a plain mintable ERC20 instead of a Pancake LP token —
//     the dividend contract only reads `balanceOf`/`totalSupply`.

contract MokeLPDividend {
    MockERC20 public immutable lpToken;
    MockERC20 public immutable usdc;

    // Accumulated dividend per LP token (scaled by 1e18).
    uint256 public totalDividendPerLP;
    // USDC received via depositDividend but not yet distributed.
    uint256 public unprocessedUsdc;

    mapping(address => uint256) public userLPRecord;
    mapping(address => uint256) public userDividendDebt;
    mapping(address => uint256) public userPendingDividend;

    event DividendDistributed(uint256 usdcAmount, uint256 totalLP, uint256 perLP);
    event DividendClaimed(address indexed user, uint256 amount);
    event UserLPSynced(address indexed user, uint256 oldLP, uint256 newLP);

    constructor(MockERC20 _lpToken, MockERC20 _usdc) {
        lpToken = _lpToken;
        usdc = _usdc;
    }

    /// @notice Anyone may sync a user's record (matches the permissionless
    /// on-chain `syncUserLP` / `batchSyncUserLP`).
    function syncUserLP(address user) external {
        _syncUserLP(user);
    }

    function _syncUserLP(address user) internal {
        uint256 currentLP = lpToken.balanceOf(user);
        uint256 recordedLP = userLPRecord[user];

        if (recordedLP > 0) {
            uint256 accumulated = recordedLP * totalDividendPerLP / 1e18;
            uint256 debt = userDividendDebt[user];
            if (accumulated > debt) {
                userPendingDividend[user] += accumulated - debt;
            }
        }

        if (currentLP != recordedLP) {
            emit UserLPSynced(user, recordedLP, currentLP);
        }

        userLPRecord[user] = currentLP;
        userDividendDebt[user] = currentLP * totalDividendPerLP / 1e18;
    }

    /// @notice Pull USDC into the contract as an unprocessed dividend pool.
    function depositDividend(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        unprocessedUsdc += amount;
    }

    /// @notice Move the unprocessed USDC pool into per-LP entitlements.
    function distributeDividend() external {
        uint256 amount = unprocessedUsdc;
        require(amount > 0, "no dividend");
        unprocessedUsdc = 0;
        uint256 totalLP = lpToken.totalSupply();
        require(totalLP > 0, "no LP");
        uint256 perLP = amount * 1e18 / totalLP;
        totalDividendPerLP += perLP;
        emit DividendDistributed(amount, totalLP, perLP);
    }

    /// @notice Sync the caller and pay out any pending dividend in USDC.
    function claimDividend() external {
        _syncUserLP(msg.sender);
        uint256 pending = userPendingDividend[msg.sender];
        require(pending > 0, "No dividend");
        userPendingDividend[msg.sender] = 0;
        usdc.transfer(msg.sender, pending);
        emit DividendClaimed(msg.sender, pending);
    }

    function getPendingDividend(address user) external view returns (uint256) {
        uint256 currentLP = lpToken.balanceOf(user);
        uint256 accumulated = currentLP * totalDividendPerLP / 1e18;
        uint256 debt = userDividendDebt[user];
        return userPendingDividend[user] + (accumulated > debt ? accumulated - debt : 0);
    }
}

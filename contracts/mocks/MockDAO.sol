// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @notice Minimal LimboDAO stand-in. FlashGovernanceArbiter only reads
/// `successfulProposal(address)` when governance is configured.
contract MockDAO {
    mapping(address => bool) public successfulProposal;

    function setSuccessfulProposal(address proposal, bool ok) external {
        successfulProposal[proposal] = ok;
    }

    function getFlashGoverner() external view returns (address) {
        return address(0);
    }
}

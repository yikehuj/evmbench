// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IFlashGovernanceArbiter {
    function burnFlashGovernanceAsset(
        address targetContract,
        address user,
        address asset,
        uint256 amount
    ) external;
}

/// @notice A passed governance proposal that slashes a flash-governance deposit.
contract MockProposal {
    function execute(
        address arbiter,
        address targetContract,
        address user,
        address asset,
        uint256 amount
    ) external {
        IFlashGovernanceArbiter(arbiter).burnFlashGovernanceAsset(
            targetContract,
            user,
            asset,
            amount
        );
    }
}

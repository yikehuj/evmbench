// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../distribution/ITokenDistributorParty.sol";

/// @notice Minimal `ITokenDistributorParty` used by the exploit harness: one
///         governance token (id 1) owned by `owner` with a 100% share.
contract MockDistributorParty is ITokenDistributorParty {
    address public owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function ownerOf(uint256) external view returns (address) {
        return owner;
    }

    function getDistributionShareOf(uint256) external pure returns (uint256) {
        return 1e18;
    }
}

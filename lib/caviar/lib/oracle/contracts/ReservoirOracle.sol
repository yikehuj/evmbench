// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Compile-only vendor stub for the Reservoir oracle base contract.
/// The upstream repository (reservoirprotocol/oracle) is no longer publicly
/// available, so this minimal definition provides the ABI surface that Caviar's
/// Pair / StolenNftFilterOracle sources import. Signature verification is not
/// implemented; the packaged tests never enable the stolen-NFT oracle.
abstract contract ReservoirOracle {
    struct Message {
        bytes32 id;
        bytes payload;
        uint256 timestamp;
        bytes signature;
    }

    address public RESERVOIR_ORACLE_ADDRESS;

    constructor(address reservoirOracleAddress) {
        RESERVOIR_ORACLE_ADDRESS = reservoirOracleAddress;
    }

    function updateReservoirOracleAddress(address newReservoirOracleAddress) public virtual;

    function _verifyMessage(bytes32, uint256, Message calldata) internal view virtual returns (bool) {
        return false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal CREATE + CREATE2 deployer used by exploit/deploy.sh to build
///         the circular Little Boy Plus world.
///
/// The LBP / LBPHashrate / vault contracts reference each other's addresses as
/// immutables, so they cannot be deployed by plain sequential CREATE. The
/// protocol's own pattern is to predict the CREATE2 addresses off-chain, deploy
/// a HashrateRegistry (regular CREATE) carrying those predictions, then deploy
/// the rest at the predicted addresses and assert the match.
///
/// The deployment script performs that dance off-chain (in bash/python) and
/// feeds each contract's init code to this factory as *calldata*. That avoids
/// embedding `type(X).creationCode` for ten contracts in a single monolithic
/// deployer, which would blow past EIP-3860's 48 KB init-code limit.
contract DeployerFactory {
    /// @notice Deploy `code` via CREATE from this factory.
    function deployCreate(bytes memory code) external returns (address addr) {
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "create failed");
    }

    /// @notice Deploy `code` via CREATE2 from this factory with `salt`.
    function deploy(bytes32 salt, bytes memory code) external returns (address addr) {
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
        }
        require(addr != address(0), "create2 failed");
    }
}

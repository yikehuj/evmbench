// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleProxy - EIP-1967 style proxy for testing
 * @dev Used to simulate the controller proxy in the exploit
 */

contract SimpleProxy {
    // EIP-1967 storage slot for implementation
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Controller-specific storage (simulated from implementation context)
    bytes32 private constant CONTROLLER_STORAGE_DAO = bytes32(uint256(1));
    bytes32 private constant CONTROLLER_STORAGE_FEES_OWNER = bytes32(uint256(2));

    constructor(address implementation) {
        _setImplementation(implementation);
    }

    function implementation() external view returns (address) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        address impl;
        assembly {
            impl := sload(slot)
        }
        return impl;
    }

    function setFeesOwner(address owner_) external {
        bytes32 slot = CONTROLLER_STORAGE_FEES_OWNER;
        assembly {
            sstore(slot, owner_)
        }
    }

    function feesOwner() external view returns (address) {
        bytes32 slot = CONTROLLER_STORAGE_FEES_OWNER;
        address owner;
        assembly {
            owner := sload(slot)
        }
        return owner;
    }

    function _setImplementation(address impl) internal {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, impl)
        }
    }

    fallback() external payable {
        bytes32 slot = IMPLEMENTATION_SLOT;
        address impl;
        assembly {
            impl := sload(slot)
        }
        _delegate(impl);
    }

    receive() external payable {
        bytes32 slot = IMPLEMENTATION_SLOT;
        address impl;
        assembly {
            impl := sload(slot)
        }
        _delegate(impl);
    }

    function _delegate(address impl) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

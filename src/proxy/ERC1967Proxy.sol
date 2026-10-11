// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal EIP-1967 proxy. Stores only the implementation address in the
// canonical slot and delegatecalls everything else, so the implementation's
// storage (including OpenZeppelin's ERC-7201 Initializable namespace) lives in
// the proxy untouched.
contract ERC1967Proxy {
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address implementation, bytes memory data) payable {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation)
        }
        if (data.length > 0) {
            (bool ok, ) = implementation.delegatecall(data);
            require(ok, 'ERC1967Proxy: init failed');
        }
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }

    function _fallback() private {
        address implementation;
        assembly {
            implementation := sload(_IMPLEMENTATION_SLOT)
        }
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

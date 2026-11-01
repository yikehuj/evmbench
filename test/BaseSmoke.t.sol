// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {AmbireAccount} from "../contracts/AmbireAccount.sol";
import {AmbireAccountFactory} from "../contracts/AmbireAccountFactory.sol";

/// @notice Constructor-agnostic smoke test. It deploys AmbireAccount by appending
/// constructor arguments to the creation code, which works both for the vulnerable
/// snapshot (constructor takes `address[]`) and for the fixed file (no constructor:
/// the appended bytes are simply ignored).
contract BaseSmokeTest is Test {
    function _deployAccount(address[] memory addrs) internal returns (AmbireAccount account) {
        bytes memory initCode = abi.encodePacked(type(AmbireAccount).creationCode, abi.encode(addrs));
        address addr;
        assembly {
            addr := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(addr != address(0), "CREATE_FAILED");
        account = AmbireAccount(payable(addr));
    }

    function test_smoke_deploysAndExposesErC165() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(this);

        AmbireAccount account = _deployAccount(addrs);

        assertGt(address(account).code.length, 0);
        assertTrue(account.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(account.supportsInterface(0x4e2312e0)); // ERC-1155 receiver
        assertEq(account.nonce(), 0);
    }

    function test_smoke_factoryIsUsable() public {
        AmbireAccountFactory factory = new AmbireAccountFactory(address(this));
        assertEq(factory.allowedToDrain(), address(this));
    }
}

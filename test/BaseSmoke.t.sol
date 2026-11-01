// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {V3Proxy, ISwapRouter, IQuoter} from "../contracts/helper/V3Proxy.sol";

/// @notice Constructor-agnostic smoke test: must pass on both the vulnerable
/// snapshot and the gold-patched snapshot. It deliberately avoids every
/// interface touched by the audit fixes.
contract BaseSmokeTest is Test {
    function test_BaseSmoke() public {
        // V3Proxy's constructor is not changed by any of the packaged fixes.
        V3Proxy proxy = new V3Proxy(ISwapRouter(address(0x1001)), IQuoter(address(0x1002)), 500);
        assertEq(proxy.feeTier(), 500);
        assertEq(address(proxy.ROUTER()), address(0x1001));
        assertEq(address(proxy.QUOTER()), address(0x1002));
    }
}

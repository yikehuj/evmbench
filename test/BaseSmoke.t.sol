// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {DSTest} from "ds-test/test.sol";

import {xETH} from "src/xETH.sol";
import {WrappedXETH} from "src/wxETH.sol";

/// @dev Constructor-agnostic smoke test: exercises wxETH stake/unstake through the
/// public interface only. It must pass on both the vulnerable base and the gold-patched tree.
contract BaseSmokeTest is DSTest {
    function test_BaseSmoke_wxETH_roundtrip() public {
        xETH token = new xETH();
        token.setAMO(address(this));

        WrappedXETH wrapped = new WrappedXETH(address(token));

        token.mintShares(1 ether);
        token.approve(address(wrapped), 1 ether);

        uint256 shares = wrapped.stake(1 ether);
        assertEq(shares, 1 ether, "unexpected initial share amount");
        assertEq(wrapped.balanceOf(address(this)), 1 ether, "shares not minted");

        uint256 received = wrapped.unstake(shares);
        assertEq(received, 1 ether, "unexpected xETH returned");
        assertEq(token.balanceOf(address(this)), 1 ether, "xETH not returned");
        assertEq(wrapped.totalSupply(), 0, "shares not burned");
    }
}

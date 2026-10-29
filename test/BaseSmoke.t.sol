// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "src/Cally.sol";

contract BaseSmoke is Test {
    Cally internal c;

    function setUp() public {
        c = new Cally();
    }

    function test_deploys_and_exposes_basic_state() public {
        assertEq(c.vaultIndex(), 1, "vaultIndex should start at 1");
        assertEq(c.feeRate(), 0, "feeRate should start at 0");
        assertEq(c.protocolUnclaimedFees(), 0, "protocolUnclaimedFees should start at 0");
        assertEq(c.premiumOptions(0), 0.01 ether, "first premium option");
        assertEq(c.strikeOptions(0), 1 ether, "first strike option");
        assertEq(c.owner(), address(this), "owner should be deployer");
    }
}

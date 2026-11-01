// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ERC20Token} from "../contracts/mocks/ERC20Token.sol";
import {RocketJoeToken} from "../contracts/RocketJoeToken.sol";
import {RocketJoeStaking} from "../contracts/RocketJoeStaking.sol";
import {LaunchEvent} from "../contracts/LaunchEvent.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {MockWAVAX, MockLaunchFactory} from "./helpers/Mocks.sol";

/// @notice Constructor-agnostic smoke tests. They must pass both on the
/// vulnerable snapshot and after the gold patches are applied, so they only use
/// interfaces that the patches leave untouched.
contract BaseSmokeTest is Test {
    function test_Smoke_StakingDepositWithdraw() public {
        ERC20Token joe = new ERC20Token();
        RocketJoeToken rJoe = new RocketJoeToken();
        RocketJoeStaking staking = new RocketJoeStaking();

        rJoe.transferOwnership(address(staking));
        staking.initialize(
            IERC20Upgradeable(address(joe)),
            rJoe,
            0,
            block.timestamp + 1
        );

        vm.warp(block.timestamp + 10);
        joe.mint(address(this), 100 ether);
        joe.approve(address(staking), 100 ether);

        staking.deposit(100 ether);
        assertEq(joe.balanceOf(address(staking)), 100 ether);

        staking.withdraw(100 ether);
        assertEq(joe.balanceOf(address(this)), 100 ether);
    }

    function test_Smoke_LaunchEventDeposit() public {
        MockWAVAX wavax = new MockWAVAX();
        ERC20Token token = new ERC20Token();
        MockLaunchFactory factory = new MockLaunchFactory(
            address(wavax),
            address(0xBEEF),
            address(0xBEEF),
            address(token),
            0,
            100,
            10,
            100,
            address(0xCAFE)
        );

        LaunchEvent ev = new LaunchEvent();
        token.mint(address(ev), 105 ether);
        uint256 start = block.timestamp + 10;
        vm.prank(address(factory));
        ev.initialize(
            address(0x1111),
            start,
            address(token),
            0,
            0,
            1e17,
            1e17,
            100 ether,
            1,
            2
        );

        vm.warp(start + 1);
        ev.depositAVAX{value: 1 ether}();

        (uint256 avaxReserve, uint256 tokenReserve) = ev.getReserves();
        assertEq(avaxReserve, 1 ether);
        assertEq(tokenReserve, 105 ether);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Scenario.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys the dex with a funded victim reserve and views.
    function testScenarioExposesDexStateViews() public {
        Scenario scenario = new Scenario();
        assert(scenario.victim() == address(scenario.dex()));
        assert(scenario.assetAddress() == address(scenario.asset()));
        assert(scenario.reserveBalance() == 1000000 ether);
        assert(scenario.attackerBalance(address(scenario)) == 1000000 ether);
        assert(scenario.dex().liquidity() == 0);
    }

    /// The admin-routed user command still moves the caller's own funds
    /// through the dex and tracks liquidity.
    function testAuthorizedUserCmdMovesCallerFunds() public {
        CrocAsset asset = new CrocAsset();
        CrocSwapDex dex = new CrocSwapDex(asset);
        asset.mint(address(this), 100 ether);
        asset.approve(address(dex), 100 ether);
        address receiver = address(0xBEEF);
        uint256 receiverBefore = asset.balanceOf(receiver);
        dex.userCmd(address(this), 40 ether, receiver);
        assert(asset.balanceOf(receiver) == receiverBefore + 40 ether);
        assert(asset.balanceOf(address(this)) == 60 ether);
        assert(dex.liquidity() == 40 ether);
    }
}

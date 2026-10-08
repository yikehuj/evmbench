// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Scenario.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The scenario fixture seeds the target and itself with the asset.
    function testScenarioFixtureViews() public {
        Scenario scenario = new Scenario();
        assert(address(scenario.asset()) != address(0));
        assert(address(scenario.target()) != address(0));
        assert(scenario.victim() == address(scenario.target()));
        assert(scenario.reserveBalance() == 1000000 ether);
        assert(scenario.attackerBalance(address(scenario)) == 1000000 ether);
        assert(scenario.assetAddress() == address(scenario.asset()));
        assert(scenario.target().oraclePrice() == 0);
    }

    /// The administrator can still set the oracle data and the seeded
    /// borrow path pays out to the recipient when the price gate holds.
    function testAdminSetsOracleAndBorrowPaysOut() public {
        RikkeiAsset asset = new RikkeiAsset();
        RikkeiCointroller target = new RikkeiCointroller(asset);
        assert(target.admin() == address(this));
        asset.mint(address(target), 1000 ether);

        target.setOracleData(address(asset), 1000);
        assert(target.oraclePrice() == 1000);

        address recipient = address(0xBEEF);
        uint256 before = asset.balanceOf(recipient);
        target.borrow(recipient, 40 ether);
        assert(asset.balanceOf(recipient) == before + 40 ether);
        assert(asset.balanceOf(address(target)) == 960 ether);
    }
}

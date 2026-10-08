pragma solidity ^0.8.17;

import "../src/Scenario.sol";

interface VmWarp {
    function warp(uint256) external;
}

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys with a funded pool, a tracked reserve and views.
    function testScenarioExposesPoolStateViews() public {
        Scenario scenario = new Scenario();
        assert(address(scenario.token()) != address(0));
        assert(address(scenario.pair()) != address(0));
        assert(scenario.victim() == address(scenario.pair()));
        assert(scenario.asset() == address(scenario.token()));
        assert(scenario.reserveBalance() > 0);
        assert(scenario.victimBalance() > 0);
    }

    /// skim still pays out a genuine deposit excess above the tracked reserve.
    function testSkimWithdrawsGenuineDepositExcess() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        WDOGE token = new WDOGE();
        PairMock pair = new PairMock(token, 800 ether);
        token.transfer(address(pair), 1000 ether);
        uint256 pairBalance = token.balanceOf(address(pair));
        assert(pairBalance > pair.reserveBalance());
        uint256 before = token.balanceOf(address(this));
        pair.skim(address(this));
        assert(token.balanceOf(address(this)) > before);
        assert(token.balanceOf(address(pair)) < pairBalance);
    }
}

pragma solidity 0.7.5;

import "../src/Scenario.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys a seeded staking pool with empty accounting.
    function testScenarioSeedsStakingPool() public {
        Scenario s = new Scenario();
        assert(address(s.staking()) != address(0));
        assert(address(s.stakeToken()) != address(0));
        assert(s.victim() == address(this));
        assert(s.seededAmount() == 700000 ether);
        assert(s.stakeToken().balanceOf(address(s.staking())) == 700000 ether);
        assert(s.staking().totalSupply() == 0);
        assert(s.staking().balanceOf(address(this)) == 0);
    }

    /// A genuine staker can start farming, stake, and withdraw the full
    /// stake; pool accounting returns to zero and tokens come back.
    function testStakeAndWithdrawRoundTrip() public {
        MockStakeToken st = new MockStakeToken(address(this), 1000 ether);
        MockRewardToken rt = new MockRewardToken();
        StakingRewards sr =
            new StakingRewards(address(this), address(this), address(st), address(rt));
        st.approve(address(sr), 1000 ether);
        sr.notifyRewardAmount(2592000 ether); // starts the 30-day farming period

        sr.stake(600 ether);
        assert(sr.totalSupply() == 600 ether);
        assert(sr.balanceOf(address(this)) == 600 ether);
        assert(st.balanceOf(address(sr)) == 600 ether);
        assert(st.balanceOf(address(this)) == 400 ether);

        sr.withdraw(600 ether);
        assert(sr.totalSupply() == 0);
        assert(sr.balanceOf(address(this)) == 0);
        assert(st.balanceOf(address(this)) == 1000 ether);
        assert(st.balanceOf(address(sr)) == 0);
    }
}

pragma solidity ^0.8.20;
import "../src/Scenario.sol";

interface VmWarp { function warp(uint256) external; }

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys with a fully seeded target reserve and views.
    function testScenarioSeedsTargetReserve() public {
        Scenario scenario = new Scenario();
        assert(scenario.assetAddress() != address(0));
        assert(address(scenario.target()) != address(0));
        assert(scenario.victim() == address(scenario.target()));
        assert(scenario.reserveBalance() == scenario.SEED());
        assert(scenario.target().reserve() == scenario.SEED());
        assert(scenario.attackerBalance(address(this)) == 0);
    }

    /// The target's withdrawal boundary still moves assets for the authorized owner.
    function testOwnerWithdrawTransfersAssets() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        FixtureToken token = new FixtureToken();
        VulnerableTarget tgt = new VulnerableTarget(token);
        // this contract owns the target it deployed
        assert(tgt.owner() == address(this));
        address holder = address(0xBEEF);
        token.mint(holder, 50 ether);
        uint256 receiverBefore = token.balanceOf(address(this));
        tgt.withdrawFrom(holder, 50 ether, address(this));
        assert(token.balanceOf(address(this)) == receiverBefore + 50 ether);
        assert(token.balanceOf(holder) == 0);
        assert(tgt.reserve() == 0);
    }

    /// The owner path through the Scenario still settles the seeded withdrawal.
    function testScenarioOwnerWithdrawSettles() public {
        Scenario scenario = new Scenario();
        uint256 treasuryBefore = scenario.reserveBalance();
        scenario.attack(address(this));
        assert(scenario.attackerBalance(address(this)) >= treasuryBefore / 2);
        assert(scenario.reserveBalance() + scenario.attackerBalance(address(this)) == treasuryBefore);
    }
}

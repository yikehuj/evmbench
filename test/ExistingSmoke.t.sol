pragma solidity ^0.8.20;
import "../src/Scenario.sol";
import {Staking, User} from "../src/Staking.sol";
interface VmWarp { function warp(uint256) external; }

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    VmWarp constant VM = VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    receive() external payable {}

    /// The fixture deploys the staking system with owned xLoot IDs and a
    /// funded LOOT wallet; views report the seeded state.
    function testScenarioFixtureViews() public {
        VM.warp(2 days);
        Scenario s = new Scenario();
        assert(s.attacker() == address(this));
        assert(address(s.staking()) != address(0));
        assert(address(s.loot()) != address(0));
        assert(address(s.xloot()) != address(0));
        (address xlootToken, , , uint256 supply) = s.staking().xloot();
        assert(xlootToken == address(s.xloot()));
        assert(supply == 2);
        assert(s.xloot().balanceOf(address(this)) == 2);
        assert(s.staking().nextEpocId() == 1);
        assert(s.loot().balanceOf(address(this)) >= 1000 ether);
        User memory u0 = s.staking().user(address(this));
        assert(u0.amount == 0);
    }

    /// Staking and unstaking LOOT keeps user accounting consistent.
    function testStakeAndUnstakeRoundTrip() public {
        VM.warp(2 days);
        Scenario s = new Scenario();
        LootMock loot = s.loot();
        Staking staking = s.staking();
        loot.approve(address(staking), 1000 ether);
        staking.stake(1000 ether);
        User memory u = staking.user(address(this));
        assert(u.amount == 1000 ether);
        assert(u.points > 0);
        assert(staking.totalUser() == 1);
        assert(loot.balanceOf(address(staking)) == 1000 ether);

        staking.unstake(400 ether);
        u = staking.user(address(this));
        assert(u.amount == 600 ether);
        assert(staking.totalUser() == 1);
        assert(loot.balanceOf(address(this)) == s.STAKE() + 400 ether);
    }

    /// A redemption of distinct owned xLoot IDs is accepted and pays the
    /// committed epoch revenue once; re-submitting in the same epoch pays
    /// nothing further.
    function testRedeemDistinctOwnedIdsPaysOnce() public {
        VM.warp(2 days);
        Scenario s = new Scenario();
        Staking staking = s.staking();
        (bool sent, ) = address(staking).call{value: 1 ether}(""); // commits epoch 1 revenue
        require(sent, "revenue send failed");
        assert(staking.nextEpocId() == 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256 before = address(this).balance;
        staking.redeem(ids);
        uint256 paid = address(this).balance - before;
        assert(paid > 0);
        assert(paid < 1 ether);
        assert(address(staking).balance < 1 ether);

        uint256[] memory repeat = new uint256[](1);
        repeat[0] = 1;
        staking.redeem(repeat); // already redeemed this epoch: no double pay
        assert(address(this).balance - before == paid);
    }
}

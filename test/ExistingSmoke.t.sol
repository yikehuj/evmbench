interface VmWarp { function warp(uint256) external; }
pragma solidity 0.6.10;
import "../src/Scenario.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys a funded two-component CK token, a live module
    /// and a seeded exchange reserve.
    function testScenarioFixtureIsFunded() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        assert(address(scenario.issueToken()) != address(0));
        assert(address(scenario.reserveToken()) != address(0));
        assert(address(scenario.ckToken()) != address(0));
        assert(address(scenario.module()) != address(0));
        assert(address(scenario.exchange()) != address(0));
        address[] memory components = scenario.ckToken().getComponents();
        assert(components.length == 2);
        assert(scenario.reserveBalance() == scenario.SEED());
        assert(scenario.issueToken().balanceOf(address(scenario)) == scenario.SEED());
        assert(scenario.issueToken().balanceOf(address(scenario.ckToken())) == scenario.SEED());
        assert(scenario.attackerBalance(address(this)) == 0);
    }

    /// Issuance whose weightings sum to exactly one precise unit is a normal
    /// distribution: CK is minted to the issuer, the reserve component is
    /// bought through the exchange and the issue token stays escrowed in the
    /// CK token.
    function testIssueWithBalancedWeightingsStillMints() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        MockERC20 issueToken = scenario.issueToken();
        issueToken.mint(address(this), 10 ether);
        issueToken.approve(address(scenario.module()), uint256(-1));

        address[] memory midTokens = new address[](2);
        uint256[] memory weightings = new uint256[](2);
        weightings[0] = 0.5 ether;
        weightings[1] = 0.5 ether;

        scenario.module().issueWithSingleToken2(
            address(scenario.ckToken()),
            address(issueToken),
            1 ether,
            0,
            midTokens,
            weightings,
            address(this),
            true
        );

        assert(scenario.attackerBalance(address(this)) > 0);
        assert(scenario.reserveBalance() < scenario.SEED());
        assert(scenario.reserveToken().balanceOf(address(scenario.ckToken())) > 0);
        assert(scenario.issueToken().balanceOf(address(scenario.ckToken())) > scenario.SEED());
    }
}

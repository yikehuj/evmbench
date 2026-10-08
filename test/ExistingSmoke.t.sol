interface VmWarp { function warp(uint256) external; }
pragma solidity 0.8.17;
import "../src/Scenario.sol";
import "../src/AccountLiquidator.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys a liquidator behind a proxy with a funded victim
    /// and a price-bearing genuine reserve.
    function testScenarioExposesLiquidatorViews() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        assert(address(scenario.liquidator()) != address(0));
        assert(scenario.victim() != address(0));
        assert(scenario.victimCollateral() == 100 ether);
        assert(scenario.reserveBalance() == 1000 ether);
        assert(scenario.liquidator().getLatestPrice(address(scenario.realReserve())) == 1e8);
        (uint256 cost, uint256 penalty) =
            scenario.liquidator().computeCostOfLiquidation(scenario.victim(), address(scenario.realReserve()));
        assert(cost > 0);
        assert(penalty > 0);
    }

    /// A liquidation routed through a genuine (approved) reserve still
    /// transfers penalty collateral to the liquidator and burns debt.
    function testLiquidationViaGenuineReservePaysLiquidator() public {
        MockToken token = new MockToken();
        MockAssets assets = new MockAssets();
        MockHouseCoin house = new MockHouseCoin(address(token));
        AccountLiquidator implementation = new AccountLiquidator();
        SimpleProxy proxy = new SimpleProxy(
            address(implementation),
            abi.encodeWithSignature("initialize(address,address)", address(house), address(assets))
        );
        AccountLiquidator liquidator = AccountLiquidator(address(proxy));
        MockReserve reserve = new MockReserve(address(token), address(token), 11, 12, 1e8);

        // Patched builds only accept registered reserves; the baseline has no
        // setter, so the call is a silent no-op there.
        address(liquidator).call(
            abi.encodeWithSignature("setApprovedReserve(address,bool)", address(reserve), true)
        );

        address user = address(0x1234);
        uint256 collateral = 100 ether;
        assets.mint(user, 11, collateral);
        assets.mint(user, 12, collateral);
        token.mint(address(this), collateral);
        token.approve(address(liquidator), type(uint256).max);

        liquidator.liquidateUser(user, address(reserve));

        assert(assets.bal(11, address(this)) > 0);
        assert(assets.bal(11, user) < collateral);
        assert(token.balanceOf(address(this)) < collateral);
    }
}

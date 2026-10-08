pragma solidity ^0.8.19;
import "../src/Scenario.sol";

interface VmWarp { function warp(uint256) external; }

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke is ITesseraSwapCallback {
    TesseraSwap private activeSwap;
    MockERC20 private payToken;

    /// The fixture deploys with a funded treasury and guarded admin controls.
    function testScenarioDeploysFundedFixture() public {
        Scenario scenario = new Scenario();
        assert(address(scenario.weth()) != address(0));
        assert(address(scenario.usdc()) != address(0));
        assert(address(scenario.engine()) != address(0));
        assert(address(scenario.pool()) != address(0));
        assert(address(scenario.tessera()) != address(0));
        assert(scenario.asset() == address(scenario.usdc()));
        assert(scenario.reserveBalance() == scenario.SEED());
        assert(scenario.attackerBalance(address(this)) == 0);
        // owner-only engine rotation stays guarded for non-owners
        (bool ok,) = address(scenario.tessera()).call(
            abi.encodeWithSignature("changeTesseraEngine(address)", address(1))
        );
        assert(!ok);
    }

    /// An honest callback swap pays the quoted output and settles the input leg.
    function testHonestCallbackSwapSettlesBothLegs() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        MockERC20 weth = scenario.weth();
        MockERC20 usdc = scenario.usdc();
        TesseraSwap tessera = scenario.tessera();
        activeSwap = tessera;
        payToken = weth;

        // fund the trader with the WETH input it must deliver
        weth.mint(address(this), 5 ether);

        uint256 treasuryUsdcBefore = usdc.balanceOf(scenario.treasury());
        uint256 treasuryWethBefore = weth.balanceOf(scenario.treasury());
        uint256 traderWethBefore = weth.balanceOf(address(this));

        tessera.tesseraSwapWithCallback(
            address(weth), address(usdc), int256(1 ether), 0, address(this), bytes(""), bytes("")
        );

        // the quoted output reaches the recipient
        assert(usdc.balanceOf(address(this)) >= 2 ether);
        // the treasury pays out the quoted output and keeps the quoted input
        assert(treasuryUsdcBefore - usdc.balanceOf(scenario.treasury()) == 2 ether);
        assert(weth.balanceOf(scenario.treasury()) == treasuryWethBefore + 1 ether);
        assert(weth.balanceOf(address(this)) + 1 ether == traderWethBefore);
    }

    /// The view quote mirrors the engine's deterministic amounts.
    function testViewAmountsQuoteMatchesEngine() public {
        Scenario scenario = new Scenario();
        TesseraSwap tessera = scenario.tessera();
        (uint256 amountIn, uint256 amountOut) =
            tessera.tesseraSwapViewAmounts(address(scenario.weth()), address(scenario.usdc()), int256(1 ether));
        assert(amountIn > 0);
        assert(amountOut > 0);
        assert(amountOut > amountIn);
    }

    function tesseraSwapCallback(int256 amountIn, int256 amountOut, bytes calldata) external {
        require(msg.sender == address(activeSwap), "bad caller");
        require(amountIn > 0 && amountOut < 0, "bad amounts");
        payToken.transfer(msg.sender, uint256(amountIn));
    }
}

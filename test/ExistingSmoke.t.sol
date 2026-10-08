interface VmWarp { function warp(uint256) external; }
pragma solidity 0.8.11;
import "../src/Scenario.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETHMint { function mint(address, uint256) external; }

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys a whitelisted enabler and a seeded WETH reservoir.
    function testScenarioDeploysSeededReservoir() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        assert(address(scenario.enabler()) != address(0));
        assert(address(scenario.weth()) != address(0));
        assert(scenario.reserveBalance() == 100 ether);
        assert(scenario.attackerBalance(address(this)) == 0);
        assert(scenario.enabler().moduleWhitelist(address(scenario.weth())));
        assert(scenario.weth().allowance(address(scenario), address(scenario.enabler())) == type(uint256).max);
    }

    /// The documented gasless flow still works: the enabler pulls the signer's
    /// tokens via the ERC20 transfer list and executes a whitelisted module
    /// call that is not a transferFrom payload.
    function testGaslessTransfersAndBenignModuleExecution() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        MockWETH weth = scenario.weth();
        GaslessReservoirEnabler enabler = scenario.enabler();

        weth.mint(address(this), 10 ether);
        weth.approve(address(enabler), type(uint256).max);

        GaslessReservoirEnabler.ERC20Transfer[] memory transfers =
            new GaslessReservoirEnabler.ERC20Transfer[](1);
        transfers[0] = GaslessReservoirEnabler.ERC20Transfer(IERC20(address(weth)), 1 ether);

        GaslessReservoirEnabler.ExecutionInfo[] memory executions =
            new GaslessReservoirEnabler.ExecutionInfo[](1);
        executions[0] = GaslessReservoirEnabler.ExecutionInfo(
            address(weth),
            abi.encodeWithSelector(IWETHMint.mint.selector, address(this), 5 ether),
            0
        );

        enabler.erc20WithTransfersAndExecute(transfers, executions);

        assert(weth.balanceOf(address(enabler)) == 1 ether);
        assert(weth.balanceOf(address(this)) == 14 ether);
        assert(scenario.reserveBalance() == 100 ether);
    }

    /// Whitelist administration keeps working for the enabler admin.
    function testAdminManagesModuleWhitelist() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        GaslessReservoirEnabler enabler = new GaslessReservoirEnabler(address(this));
        MockWETH token = new MockWETH();
        assert(!enabler.moduleWhitelist(address(token)));
        enabler.setModuleWhitelistStatus(address(token), true);
        assert(enabler.moduleWhitelist(address(token)));
        enabler.setModuleWhitelistStatus(address(token), false);
        assert(!enabler.moduleWhitelist(address(token)));
    }
}

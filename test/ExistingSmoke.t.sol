pragma solidity ^0.6.6;

import "../src/Scenario.sol";
import "../src/ACOWriter.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The scenario fixture deploys the writer, ACO and collateral mocks.
    function testScenarioFixtureViews() public {
        Scenario scenario = new Scenario();
        assert(address(scenario.writer()) != address(0));
        assert(address(scenario.assetAddress()) != address(0));
        assert(address(scenario.aco()) != address(0));
        assert(scenario.victim() == address(scenario));
        assert(scenario.victimBalance() == 1000000000);
        ACOWriter writer = scenario.writer();
        assert(writer.weth() == address(0));
        assert(writer.erc20proxy() == address(0x0000000000000000000000000000000000001234));
    }

    /// write() still completes the legitimate premium flow through the
    /// configured 0x ERC20 proxy: ether collateral mints the ACO tokens to
    /// the sender and the writer balance is forwarded to the trusted exchange.
    function testWriteForwardsToTrustedExchange() public {
        MockERC20 strike = new MockERC20();
        MockACO aco = new MockACO(address(strike));
        TrustedExchange exchange = new TrustedExchange();
        ACOWriter writer = new ACOWriter(address(0), address(exchange));
        writer.write{value: 2}(address(aco), 1, address(exchange), "");
        assert(aco.balanceOf(address(this)) == 1);
        assert(address(aco).balance == 1);
        assert(address(exchange).balance == 1);
        assert(address(writer).balance == 0);
        assert(strike.balanceOf(address(this)) == 0);
    }
}

contract TrustedExchange {
    receive() external payable {}
}

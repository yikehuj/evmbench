// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISquidMulticall} from "../interfaces/ISquidMulticall.sol";
import {SquidMulticall} from "../src/SquidMulticall.sol";
import {Scenario} from "../src/Scenario.sol";
import {SeededToken} from "../src/SeededToken.sol";

contract CallReceiver {
    uint256 public pings;

    function note() external payable {
        pings++;
    }

    receive() external payable {}
}

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    /// The fixture deploys the multicall and seeds the victim balance plus
    /// the standing allowance the multicall may spend.
    function testScenarioSeedsVictimBalanceAndAllowance() public {
        Scenario s = new Scenario();
        assert(address(s.multicall()) != address(0));
        assert(address(s.token()) != address(0));
        assert(s.token().balanceOf(s.VICTIM()) == 100 ether);
        assert(s.token().allowance(s.VICTIM(), address(s.multicall())) == type(uint256).max);
        assert(s.token().balanceOf(address(s.multicall())) == 0);
    }

    /// The deployer-authorized multicall still collects the caller's token
    /// balance and forwards its full native balance in a call set.
    function testDeployerMulticallCollectsAndForwardsFunds() public {
        CallReceiver receiver = new CallReceiver();
        SquidMulticall multicall = new SquidMulticall();
        SeededToken token = new SeededToken(address(this), address(multicall), 100 ether);

        ISquidMulticall.Call[] memory calls = new ISquidMulticall.Call[](2);
        calls[0].callType = ISquidMulticall.CallType.CollectTokenBalance;
        calls[0].payload = abi.encode(address(token));
        calls[1].callType = ISquidMulticall.CallType.FullNativeBalance;
        calls[1].target = address(receiver);
        calls[1].callData = abi.encodeWithSignature("note()");

        multicall.run{value: 1 ether}(calls);

        assert(token.balanceOf(address(multicall)) == 100 ether);
        assert(token.balanceOf(address(this)) == 0);
        assert(receiver.pings() == 1);
        assert(address(receiver).balance == 1 ether);
    }
}

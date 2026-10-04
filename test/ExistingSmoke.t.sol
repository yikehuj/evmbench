interface VmWarp { function warp(uint256) external; }
pragma solidity ^0.6.6;

import "../src/Scenario.sol";

interface Vm { function deal(address who, uint256 newBalance) external; }

contract PatchTest {
    function testRejectsUntrustedExchange() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).deal(address(this), 1 ether);
        Scenario scenario = new Scenario();
        (bool funded,) = address(scenario).call{value: 1}("");
        require(funded, "scenario funding failed");
        (bool ok,) = address(scenario).call(
            abi.encodeWithSignature("attack(address)", address(this))
        );
        require(!ok, "untrusted exchange callback must be rejected");
    }
}

interface VmWarp { function warp(uint256) external; }
pragma solidity ^0.8.19;
import "../src/Scenario.sol";

interface IScenarioAttack { function attack(address receiver) external; }
contract ExternalAttacker {
    function run(address scenario) external returns (bool ok) {
        (ok,) = address(scenario).call(abi.encodeWithSignature("attack(address)", address(this))); require(!ok, "patched attack unexpectedly succeeded");
    }
}
contract PatchTest {
    function testPatchedAttackReverts() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        ExternalAttacker attacker = new ExternalAttacker();
        (bool ok,) = address(attacker).call(abi.encodeWithSignature("run(address)", address(scenario)));
        require(ok, "caller execution failed");

    }
}

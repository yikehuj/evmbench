interface VmWarp { function warp(uint256) external; }
pragma solidity ^0.8.17;

import "../src/Scenario.sol";

contract PatchTest {
    function testSkimCannotWithdrawTrackedReserve() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario scenario = new Scenario();
        (bool ok,) = address(scenario).call(
            abi.encodeWithSignature("attack(address)", address(this))
        );
        require(!ok, "skim must not withdraw the tracked reserve");
    }
}

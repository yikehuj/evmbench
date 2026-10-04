pragma solidity ^0.8.20;
import "../src/Scenario.sol";
interface VmWarp { function warp(uint256) external; }
contract PatchTest {
    function testPatchedGuard() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        Scenario s = new Scenario();
        uint256[] memory ids = new uint256[](2); ids[0] = 1; ids[1] = 1;
        (bool ok,) = address(s.staking()).call(abi.encodeWithSignature("redeem(uint256[])", ids));
        require(!ok, "duplicate xLoot accepted");
    }
}

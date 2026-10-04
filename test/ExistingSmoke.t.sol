interface VmWarp { function warp(uint256) external; }
pragma solidity 0.7.5;
import "../src/Scenario.sol";
contract PatchTest { function testPatchedGuard() public { Scenario s=new Scenario(); address st=address(s.staking()); (bool ok,)=st.call(abi.encodeWithSignature("withdraw(uint256)",700000 ether)); require(!ok,"zero stake withdrawal accepted"); } }
interface VmWarp { function warp(uint256) external; }
pragma solidity ^0.8.23;
import "../src/Scenario.sol";
contract PatchTest { struct Call { uint8 callType; address target; uint256 value; bytes callData; bytes payload; } function testPatchedGuard() public { Scenario s=new Scenario(); Call[] memory c=new Call[](0); (bool ok,)=address(s.multicall()).call(abi.encodeWithSignature("run((uint8,address,uint256,bytes,bytes)[])",c)); require(!ok,"unauthorized multicall accepted"); } }
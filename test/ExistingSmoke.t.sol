interface VmWarp { function warp(uint256) external; }
pragma solidity ^0.8.23;
import "../src/Scenario.sol";
contract PatchTest { function testPatchedGuard() public { Scenario s=new Scenario(); bytes memory sig=new bytes(65); sig[64]=bytes1(uint8(27)); (bool ok,)=address(s.nft()).call(abi.encodeWithSignature("cliamRewred(address,uint256,uint256,uint256,string,bytes)",address(s.mon()),1,0,block.timestamp,"",sig)); require(!ok,"malformed signature accepted"); } }
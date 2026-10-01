// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
interface IERC20Like { function transfer(address,uint256) external returns(bool); }
/// @notice Verified LegendaryMoneyMonNft behavior: reward claims are signer-gated.
contract LegendaryMoneyMonNft {
 address public owner; address public admin;
 constructor(address _owner){owner=_owner; admin=address(0);}
 modifier onlyOwner(){require(msg.sender==owner,"Ownable: caller is not the owner");_;}
 function changeadmin(address a) external onlyOwner { admin=a; }
 function cliamRewred(address payment,uint256 amount,uint256 nftid,uint256 time,string calldata exname,bytes calldata signature) external {
  require(verify(payment,msg.sender,nftid,amount,time,exname,signature),"verify failed");
  require(IERC20Like(payment).transfer(msg.sender,amount),"transfer failed");
 }
 function verify(address payment,address user,uint nftid,uint amount,uint time,string memory exname,bytes memory sig) public view returns(bool){
  bytes32 h=keccak256(abi.encodePacked(address(this),payment,user,nftid,amount,time,exname));
  return recoverSigner(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",h)),sig)==admin;
 }
 function recoverSigner(bytes32 hash,bytes memory sig) internal pure returns(address){ if(sig.length!=65)return address(0); bytes32 r;bytes32 s;uint8 v;assembly{r:=mload(add(sig,32)) s:=mload(add(sig,64)) v:=byte(0,mload(add(sig,96)))} return ecrecover(hash,v,r,s); }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
contract MockERC20 {
 string public name; string public symbol; uint8 public immutable decimals;
 uint256 public totalSupply; mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
 constructor(string memory n,string memory s,uint8 d){name=n;symbol=s;decimals=d;}
 function mint(address to,uint256 a) external {balanceOf[to]+=a; totalSupply+=a; emit Transfer(address(0),to,a);}
 function approve(address s,uint256 a) external returns(bool){allowance[msg.sender][s]=a;emit Approval(msg.sender,s,a);return true;}
 function transfer(address to,uint256 a) external returns(bool){return transferFrom(msg.sender,to,a);}
 function transferFrom(address f,address t,uint256 a) public returns(bool){require(balanceOf[f]>=a,"bal"); if(msg.sender!=f){require(allowance[f][msg.sender]>=a,"allow"); allowance[f][msg.sender]-=a;} balanceOf[f]-=a;balanceOf[t]+=a;emit Transfer(f,t,a);return true;}
 event Transfer(address indexed from,address indexed to,uint256 value); event Approval(address indexed owner,address indexed spender,uint256 value);
}

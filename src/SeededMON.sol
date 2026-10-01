// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
contract SeededMON {
 string public name="Moneymon"; string public symbol="MON"; uint8 public constant decimals=18; uint256 public totalSupply;
 mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
 constructor(address holder,uint256 amount){totalSupply=amount; balanceOf[holder]=amount; emit Transfer(address(0),holder,amount);}
 function transfer(address to,uint256 a) external returns(bool){_move(msg.sender,to,a);return true;}
 function approve(address s,uint256 a) external returns(bool){allowance[msg.sender][s]=a;emit Approval(msg.sender,s,a);return true;}
 function transferFrom(address f,address t,uint256 a) external returns(bool){uint x=allowance[f][msg.sender];require(x>=a,"allowance");if(x!=type(uint256).max){allowance[f][msg.sender]=x-a;} _move(f,t,a);return true;}
 function _move(address f,address t,uint a) internal {require(balanceOf[f]>=a,"balance");balanceOf[f]-=a;balanceOf[t]+=a;emit Transfer(f,t,a);} event Transfer(address indexed from,address indexed to,uint256 value);event Approval(address indexed owner,address indexed spender,uint256 value);
}

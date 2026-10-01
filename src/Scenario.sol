// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BoostedUSD { mapping(address=>uint256) public balanceOf; string public constant name="BoostedUSD"; string public constant symbol="BoostedUSD"; uint8 public constant decimals=18; function mint(address to,uint256 a) external{balanceOf[to]+=a;} function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a,"balance");balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;} function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a,"balance");balanceOf[f]-=a;balanceOf[t]+=a;return true;} }

contract BalancerBoostedPool { BoostedUSD public immutable asset; constructor(BoostedUSD a){asset=a;} function batchSwap(address receiver,uint256 amount) external { asset.transfer(receiver,amount); } }

contract Scenario { BoostedUSD public asset; BalancerBoostedPool public pool; address public immutable owner; uint256 public constant SEED=1_000_000 ether; constructor(){owner=msg.sender;asset=new BoostedUSD();pool=new BalancerBoostedPool(asset);asset.mint(address(pool),SEED);} function attack(address receiver) external {require(msg.sender==owner,"unauthorized");pool.batchSwap(receiver,SEED/2);} function reserveBalance() external view returns(uint256){return asset.balanceOf(address(pool));} function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);} function assetAddress() external view returns(address){return address(asset);} }

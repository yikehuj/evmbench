// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
interface IERC20X { function transfer(address,uint256) external returns(bool); function balanceOf(address) external view returns(uint256); }
contract MockPair {
 address public immutable token0; address public immutable token1; uint112 private r0; uint112 private r1; uint32 private ts; uint256 public kLast; uint256 public totalSupply=1e18;
 constructor(address a,address b){ if(a<b){token0=a;token1=b;}else{token0=b;token1=a;} r0=uint112(1e24); r1=uint112(1e24); }
 function getReserves() external view returns(uint112,uint112,uint32){return(r0,r1,ts);}
 function sync() external {r0=uint112(IERC20X(token0).balanceOf(address(this)));r1=uint112(IERC20X(token1).balanceOf(address(this)));ts=uint32(block.timestamp);}
 function swap(uint256 a0,uint256 a1,address to,bytes calldata) external { require(a0==0 || a1==0,"one side"); uint256 b0=IERC20X(token0).balanceOf(address(this)); uint256 b1=IERC20X(token1).balanceOf(address(this)); if(a0>0){IERC20X(token0).transfer(to,a0); b0-=a0;} if(a1>0){IERC20X(token1).transfer(to,a1); b1-=a1;} require(b0*b1 >= uint256(r0)*uint256(r1),"K"); }
 function balanceOf(address) external view returns(uint256){return totalSupply;}
}
contract MockFactory { mapping(address=>mapping(address=>address)) public getPair; address public feeTo; function createPair(address a,address b) external returns(address p){require(getPair[a][b]==address(0));p=address(new MockPair(a,b));getPair[a][b]=p;getPair[b][a]=p;} }
contract MockRouter { address public immutable f; constructor(address x){f=x;} function factory() external view returns(address){return f;} function WETH() external pure returns(address){return address(0xBEEF);} }

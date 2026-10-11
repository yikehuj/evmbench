// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
interface IPip { function peek() external view returns(bytes32,bool); }
interface IERC20 { function transfer(address,uint256) external returns(bool); function transferFrom(address,address,uint256) external returns(bool); }
/// Trace-faithful local reduction of the recovered 42DAO Spotter boundary.
contract SpotterVault {
    address public immutable pip; address public immutable asset; address public immutable collateralToken; uint256 public spot; uint256 public constant MAT=1e18;
    constructor(address p,address a,address c){pip=p;asset=a;collateralToken=c;}
    function poke(bytes32) external { (bytes32 v,bool ok)=IPip(pip).peek(); require(ok,"invalid"); spot=uint256(v); }
    function borrow(uint256 collateral,uint256 debt) external { require(collateral>0,"collateral"); require(collateral*spot/MAT>=debt,"unsafe"); require(IERC20(collateralToken).transferFrom(msg.sender,address(this),collateral),"collateral"); require(IERC20(asset).transfer(msg.sender,debt),"pay"); }
}
contract MockPip { bytes32 public value; bool public valid; function setValue(uint256 v,bool ok) external {value=bytes32(v);valid=ok;} function peek() external view returns(bytes32,bool){return(value,valid);} }

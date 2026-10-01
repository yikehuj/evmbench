pragma solidity 0.7.5;
import {StakingRewards} from "contracts/staking/StakingRewards.sol";
contract MockStakeToken {
    string public constant name = "Seeded LP"; string public constant symbol = "sLP"; uint8 public constant decimals = 18;
    uint256 public totalSupply; mapping(address => uint256) public balanceOf; mapping(address => mapping(address => uint256)) public allowance;
    constructor(address holder, uint256 amount) { totalSupply = amount; balanceOf[holder] = amount; emit Transfer(address(0), holder, amount); }
    function transfer(address to, uint256 amount) external returns (bool) { require(balanceOf[msg.sender] >= amount); balanceOf[msg.sender] -= amount; balanceOf[to] += amount; emit Transfer(msg.sender,to,amount); return true; }
    function transferFrom(address from,address to,uint256 amount) external returns(bool) { uint256 a=allowance[from][msg.sender]; require(a>=amount && balanceOf[from]>=amount); if(a!=uint(-1)) allowance[from][msg.sender]=a-amount; balanceOf[from]-=amount; balanceOf[to]+=amount; emit Transfer(from,to,amount); return true; }
    function approve(address spender,uint256 amount) external returns(bool){allowance[msg.sender][spender]=amount;emit Approval(msg.sender,spender,amount);return true;}
    event Transfer(address indexed from,address indexed to,uint256 value); event Approval(address indexed owner,address indexed spender,uint256 value);
}
contract MockRewardToken { bool public constant ON_DEMAND_TOKEN = true; uint256 public constant maxAllowedTotalSupply = uint(-1); mapping(address=>uint256) public balanceOf; function mint(address to,uint256 amount) external { balanceOf[to]+=amount; } }
contract Scenario {
    StakingRewards public staking; MockStakeToken public stakeToken; MockRewardToken public rewardToken; address public victim; uint256 public seededAmount;
    constructor() { victim = msg.sender; seededAmount = 700_000 ether; MockStakeToken st = new MockStakeToken(address(this), seededAmount); MockRewardToken rt = new MockRewardToken(); StakingRewards sr = new StakingRewards(msg.sender, msg.sender, address(st), address(rt)); stakeToken = st; rewardToken = rt; staking = sr; require(st.transfer(address(sr), seededAmount)); }
    function seedToken() external view returns(address){ return address(stakeToken); }
}

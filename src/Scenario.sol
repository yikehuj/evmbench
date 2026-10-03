// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {REVLoans} from "./REVLoans.sol";
import {IREVDeployer} from "./interfaces/IREVDeployer.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IJBController} from "@bananapus/core-v5/src/interfaces/IJBController.sol";
import {IJBDirectory} from "@bananapus/core-v5/src/interfaces/IJBDirectory.sol";
import {IJBProjects} from "@bananapus/core-v5/src/interfaces/IJBProjects.sol";
import {IJBPayoutTerminal} from "@bananapus/core-v5/src/interfaces/IJBPayoutTerminal.sol";
import {JBAccountingContext} from "@bananapus/core-v5/src/structs/JBAccountingContext.sol";
import {JBRuleset} from "@bananapus/core-v5/src/structs/JBRuleset.sol";
import {JBRulesetMetadata} from "@bananapus/core-v5/src/structs/JBRulesetMetadata.sol";

address constant NATIVE = 0x000000000000000000000000000000000000EEEe;

contract MockProjects {
    address public owner;
    constructor(address owner_) { owner = owner_; }
    function setOwner(address owner_) external { owner = owner_; }
    function ownerOf(uint256) external view returns (address) { return owner; }
}

contract MockPrices {}

contract MockController {
    address public immutable prices;
    constructor(address prices_) { prices = prices_; }
    function PRICES() external view returns (address) { return prices; }
    function currentRulesetOf(uint256) external pure returns (JBRuleset memory r, JBRulesetMetadata memory m) {
        m.cashOutTaxRate = 0;
        r.metadata = 0;
    }
    function totalTokenSupplyWithReservedTokensOf(uint256) external pure returns (uint256) { return 1 ether; }
    function burnTokensOf(address, uint256, uint256, string calldata) external {}
    function mintTokensOf(uint256, uint256, address, string calldata, bool) external {}
}

contract MockDirectory {
    IJBPayoutTerminal public immutable terminal;
    constructor(IJBPayoutTerminal terminal_) { terminal = terminal_; }
    function terminalsOf(uint256) external view returns (address[] memory out) {
        out = new address[](1); out[0] = address(terminal);
    }
    function primaryTerminalOf(uint256, address) external pure returns (address) { return address(0); }
    function isTerminalOf(uint256, address t) external view returns (bool) { return t == address(terminal); }
}

contract MockDeployer {
    IJBController public immutable controller;
    IJBDirectory public immutable directory;
    IJBProjects public immutable projects;
    constructor(IJBController c, IJBDirectory d, IJBProjects p) { controller = c; directory = d; projects = p; }
    function CONTROLLER() external view returns (IJBController) { return controller; }
    function DIRECTORY() external view returns (IJBDirectory) { return directory; }
    function PROJECTS() external view returns (IJBProjects) { return projects; }
}

contract NativeTerminal {
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
    function accountingContextForTokenOf(uint256, address token) external pure returns (JBAccountingContext memory c) {
        c = JBAccountingContext({token: token, decimals: 18, currency: 61166});
    }
    function currentSurplusOf(uint256, JBAccountingContext[] memory, uint256 decimals, uint256) external pure returns (uint256) {
        // The inflated fake source is evaluated at 36 decimals, while the real source uses 18.
        return decimals > 30 ? 100 ether : 100 ether;
    }
    function useAllowanceOf(uint256, address, uint256 amount, uint256, uint256, address payable beneficiary, address payable, string calldata) external returns (uint256) {
        (bool ok,) = beneficiary.call{value: amount}(""); require(ok, "terminal depleted"); return amount;
    }
    function addToBalanceOf(uint256, address, uint256, bool, string calldata, bytes calldata) external payable {}
    function pay(uint256, address, uint256, address, uint256, string calldata, bytes calldata) external payable returns (uint256) { return 0; }
    receive() external payable {}
}

contract FakeLoanSource {
    function accountingContextForTokenOf(uint256, address token) external pure returns (JBAccountingContext memory c) {
        c = JBAccountingContext({token: token, decimals: 36, currency: 61166});
    }
    function useAllowanceOf(uint256, address, uint256 amount, uint256, uint256, address payable, address payable, string calldata) external pure returns (uint256) { return amount; }
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function allowance(address, address) external pure returns (uint256) { return 0; }
    function approve(address, uint256) external pure returns (bool) { return true; }
    function transfer(address, uint256) external pure returns (bool) { return true; }
    function pay(uint256, address, uint256, address, uint256, string calldata, bytes calldata) external payable returns (uint256) { return 0; }
}

contract Scenario {
    uint256 public constant REVNET_ID = 3;
    uint256 public constant REV_ID = 99;
    REVLoans public immutable loans;
    NativeTerminal public immutable terminal;
    FakeLoanSource public immutable fakeSource;
    MockController public immutable controller;
    MockDirectory public immutable directory;
    MockProjects public immutable projects;
    MockDeployer public immutable deployer;

    constructor() payable {
        terminal = new NativeTerminal();
        fakeSource = new FakeLoanSource();
        projects = new MockProjects(address(0));
        controller = new MockController(address(new MockPrices()));
        directory = new MockDirectory(IJBPayoutTerminal(address(terminal)));
        deployer = new MockDeployer(IJBController(address(controller)), IJBDirectory(address(directory)), IJBProjects(address(projects)));
        projects.setOwner(address(deployer));
        loans = new REVLoans(IREVDeployer(address(deployer)), REV_ID, address(this), IPermit2(address(0)), address(0));
        (bool ok,) = address(terminal).call{value: msg.value}(""); require(ok);
    }
}

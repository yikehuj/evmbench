// Scenario wrapper only: the USM and FUM contracts are the verified sources.
pragma solidity ^0.8.9;
import "./USM.sol";
import "./oracles/Oracle.sol";
contract ScenarioOracle is Oracle { uint public immutable price; constructor(uint p){price=p;} function latestPrice() external view returns(uint){return price;} }
contract Scenario {
    USM public immutable usm;
    ScenarioOracle public immutable oracle;
    constructor() payable {
        oracle = new ScenarioOracle(2000 ether);
        address[] memory none = new address[](0);
        usm = new USM(oracle, none, none);
    }
    function seed() external payable { payable(address(usm)).transfer(msg.value); }
}

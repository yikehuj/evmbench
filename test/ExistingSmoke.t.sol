interface VmWarp { function warp(uint256) external; }
pragma solidity ^0.8.20;

import "../src/Scenario.sol";

contract RikkeiCaller {
    function setOracle(address target, uint256 price) external returns (bool, bytes memory) {
        return target.call(abi.encodeWithSignature("setOracleData(address,uint256)", address(0), price));
    }
}

contract RikkeiFactory {
    function create(RikkeiAsset asset) external returns (RikkeiCointroller) {
        return new RikkeiCointroller(asset);
    }
}

contract PatchTest {
    function testUnauthorizedOracleSetterReverts() public {
        VmWarp(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).warp(2 days);
        RikkeiAsset asset = new RikkeiAsset();
        RikkeiFactory factory = new RikkeiFactory();
        RikkeiCointroller target = factory.create(asset);
        RikkeiCaller caller = new RikkeiCaller();
        (bool ok,) = caller.setOracle(address(target), 1000000);
        require(!ok, "unauthorized oracle update must revert");
    }
}

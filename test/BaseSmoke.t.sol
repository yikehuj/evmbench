// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SafEth} from "../contracts/SafEth/SafEth.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Constructor-agnostic smoke test. It only exercises the upgradeable
/// initialization path, which is identical before and after every gold patch.
contract BaseSmokeTest is Test {
    SafEth internal safEth;

    function setUp() public {
        SafEth implementation = new SafEth();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                SafEth.initialize,
                ("Asymmetry Finance ETH", "safETH")
            )
        );
        safEth = SafEth(payable(address(proxy)));
    }

    function test_BaseSmoke_Initialize() public {
        assertEq(safEth.name(), "Asymmetry Finance ETH");
        assertEq(safEth.symbol(), "safETH");
        assertEq(safEth.owner(), address(this));
        assertEq(safEth.totalSupply(), 0);
        assertEq(safEth.derivativeCount(), 0);
        assertEq(safEth.minAmount(), 5 * 10 ** 17);
        assertEq(safEth.maxAmount(), 200 * 10 ** 18);
    }
}

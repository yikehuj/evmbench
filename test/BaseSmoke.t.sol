// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {KIBToken} from "@kuma/KIBToken.sol";
import {IKUMAAddressProvider} from "@kuma/interfaces/IKUMAAddressProvider.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Minimal baseline smoke test, kept constructor-agnostic: it only
/// initializes the KIBToken behind a plain ERC1967 proxy and reads its initial
/// accounting, so it compiles and passes both before and after every gold patch.
contract BaseSmokeTest is Test {
    function _deployKIBToken() internal returns (KIBToken) {
        KIBToken implementation = new KIBToken();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),

            abi.encodeWithSelector(
                KIBToken.initialize.selector,
                "KUMA Interest Bearing Token",
                "FRK360",
                4 hours,
                IKUMAAddressProvider(address(1)),
                bytes4("EUR"),
                bytes4("FR"),
                uint64(365 days * 30)
            )
        );
        return KIBToken(address(proxy));
    }

    function test_kib_token_smoke() public {
        KIBToken kib = _deployKIBToken();

        assertGt(address(kib).code.length, 0);
        assertEq(kib.name(), "KUMA Interest Bearing Token");
        assertEq(kib.symbol(), "FRK360");
        assertEq(kib.totalSupply(), 0);
        assertEq(kib.balanceOf(address(this)), 0);
    }

    function test_kib_token_metadata_smoke() public {
        KIBToken kib = _deployKIBToken();

        assertEq(kib.decimals(), 18);
        assertEq(kib.getYield(), 1e27);
        assertEq(kib.getTotalBaseSupply(), 0);
        assertEq(kib.getEpochLength(), 4 hours);
    }
}

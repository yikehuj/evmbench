// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";

import {TimeswapFactory} from "../contracts/TimeswapFactory.sol";
import {TimeswapPair} from "../contracts/TimeswapPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal baseline smoke test. The H-04..H-07 patches only reorder
/// callback calls inside TimeswapPair.sol; the pair/factory constructors and the
/// public view interface are untouched. This smoke test therefore deploys and
/// queries the pair without any patch-specific interface, so it passes both
/// before and after the patch is applied.
contract BaseSmokeTest is Test {
    function test_pair_smoke() public {
        TimeswapFactory factory = new TimeswapFactory(address(this), 3000, 3000);

        IERC20 asset = IERC20(makeAddr("asset"));
        IERC20 collateral = IERC20(makeAddr("collateral"));

        TimeswapPair pair = TimeswapPair(address(factory.createPair(asset, collateral)));

        assertEq(address(pair.factory()), address(factory));
        assertEq(address(pair.asset()), address(asset));
        assertEq(address(pair.collateral()), address(collateral));
        assertEq(uint256(pair.fee()), 3000);
        assertEq(uint256(pair.protocolFee()), 3000);
        assertEq(address(factory.getPair(asset, collateral)), address(pair));

        (uint112 x, uint112 y, uint112 z) = pair.constantProduct(1e18);
        assertEq(uint256(x), 0);
        assertEq(uint256(y), 0);
        assertEq(uint256(z), 0);
    }
}

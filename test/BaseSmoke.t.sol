// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TestERC20} from "../contracts/test/TestERC20.sol";
import {LPToken} from "../contracts/core/connext/helpers/LPToken.sol";
import {LibDiamond} from "../contracts/core/connext/libraries/LibDiamond.sol";
import {StableSwapFacet} from "../contracts/core/connext/facets/StableSwapFacet.sol";
import {SwapAdminFacet} from "../contracts/core/connext/facets/SwapAdminFacet.sol";
import {SwapUtils} from "../contracts/core/connext/libraries/SwapUtils.sol";

/// @notice Constructor-agnostic smoke test for the curated Connext source tree.
/// @dev Exercises the stable-swap core (init, add liquidity, swap) through the
/// diamond facets without touching any interface that a gold patch changes.
/// It must pass both on the vulnerable snapshot and on the patched tree.
contract BaseSmokeTest is StableSwapFacet, SwapAdminFacet, Test {
  bytes32 internal constant CANONICAL_ID = keccak256("evmbench.base.smoke");

  address internal local;
  address internal adopted;
  address internal lpUser = address(0xBEEF);
  LPToken internal lpTokenTarget;

  function setUp() public {
    local = address(new TestERC20());
    adopted = address(new TestERC20());

    lpTokenTarget = new LPToken();
    lpTokenTarget.initialize("Smoke LP", "SLP");

    // The facets read the diamond owner from LibDiamond storage; this test
    // contract acts as both owner and pool. A distinct LP address supplies
    // liquidity so the pool balance actually increases on transferFrom.
    LibDiamond.diamondStorage().contractOwner = address(this);

    TestERC20(local).transfer(lpUser, 100 ether);
    TestERC20(adopted).transfer(lpUser, 100 ether);
  }

  function _initialize() internal {
    IERC20[] memory pooled = new IERC20[](2);
    pooled[0] = IERC20(local);
    pooled[1] = IERC20(adopted);

    uint8[] memory decimals = new uint8[](2);
    decimals[0] = 18;
    decimals[1] = 18;

    this.initializeSwap(CANONICAL_ID, pooled, decimals, "Smoke LP", "SLP", 50, 1e7, 0, address(lpTokenTarget));
  }

  function test_BaseSmoke_initializeAndAddLiquidity() public {
    _initialize();

    SwapUtils.Swap memory store = this.getSwapStorage(CANONICAL_ID);
    assertEq(store.pooledTokens.length, 2);
    assertEq(address(store.pooledTokens[0]), local);
    assertEq(address(store.pooledTokens[1]), adopted);
    assertEq(store.swapFee, 1e7);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 1 ether;
    amounts[1] = 1 ether;

    vm.startPrank(lpUser);
    IERC20(local).approve(address(this), 1 ether);
    IERC20(adopted).approve(address(this), 1 ether);
    uint256 lpMinted = this.addSwapLiquidity(CANONICAL_ID, amounts, 0, block.timestamp + 1000);
    vm.stopPrank();
    assertGt(lpMinted, 0);

    assertEq(this.getSwapTokenBalance(CANONICAL_ID, 0), 1 ether);
    assertEq(this.getSwapTokenBalance(CANONICAL_ID, 1), 1 ether);
  }

  function test_BaseSmoke_swapExact() public {
    _initialize();

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 10 ether;
    amounts[1] = 10 ether;

    vm.startPrank(lpUser);
    IERC20(local).approve(address(this), 10 ether);
    IERC20(adopted).approve(address(this), 10 ether);
    this.addSwapLiquidity(CANONICAL_ID, amounts, 0, block.timestamp + 1000);

    uint256 amountIn = 1 ether;
    uint256 expectedOut = this.calculateSwap(CANONICAL_ID, 0, 1, amountIn);

    IERC20(local).approve(address(this), amountIn);
    uint256 out = this.swapExact(CANONICAL_ID, amountIn, local, adopted, expectedOut, block.timestamp + 1000);
    vm.stopPrank();

    assertEq(out, expectedOut);
    assertGt(out, 0);
    assertLt(out, amountIn);
  }
}

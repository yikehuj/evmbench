// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import { IAToken } from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import { IRewardsController } from "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import { IPoolAddressesProviderRegistry } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProviderRegistry.sol";

import { AaveV3YieldSourceHarness } from "../contracts/test/AaveV3YieldSourceHarness.sol";
import { ERC20Mintable } from "../contracts/test/ERC20Mintable.sol";
import { MockAToken, MockPool, MockPoolAddressesProvider, MockPoolAddressesProviderRegistry } from "../contracts/test/AaveV3Mocks.sol";

/// @notice Constructor-agnostic smoke test for the curated AaveV3YieldSource snapshot.
/// @dev Deliberately avoids the interfaces touched by the M-01 gold patch
///      (supplyTokenTo deposit accounting), so it compiles and passes on both
///      the vulnerable and the fixed source.
contract BaseSmokeTest is Test {
  ERC20Mintable internal token;
  MockAToken internal aToken;
  MockPool internal pool;
  MockPoolAddressesProvider internal provider;
  MockPoolAddressesProviderRegistry internal registry;
  AaveV3YieldSourceHarness internal yieldSource;

  function setUp() public {
    token = new ERC20Mintable("Mock Token", "MOCK", 18);
    aToken = new MockAToken(address(token));
    pool = new MockPool(address(aToken));
    provider = new MockPoolAddressesProvider(address(pool));
    registry = new MockPoolAddressesProviderRegistry(address(provider));

    yieldSource = new AaveV3YieldSourceHarness(
      IAToken(address(aToken)),
      IRewardsController(address(0xBEEF)),
      IPoolAddressesProviderRegistry(address(registry)),
      "PoolTogether aToken Yield Source",
      "pTAYS",
      18,
      address(this)
    );
  }

  function test_BaseSmoke() public {
    assertEq(yieldSource.name(), "PoolTogether aToken Yield Source");
    assertEq(yieldSource.symbol(), "pTAYS");
    assertEq(yieldSource.decimals(), 18);
    assertEq(yieldSource.depositToken(), address(token));
    assertEq(yieldSource.totalSupply(), 0);

    yieldSource.mint(address(this), 5e18);
    assertEq(yieldSource.totalSupply(), 5e18);
    assertEq(yieldSource.balanceOf(address(this)), 5e18);
  }
}

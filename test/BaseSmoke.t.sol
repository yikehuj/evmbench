// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StrategySupplyERC4626 } from "../contracts/core/strategies/StrategySupplyERC4626.sol";
import { ERC20Mock } from "../contracts/mocks/ERC20Mock.sol";
import { ERC4626VaultMock } from "../contracts/mocks/ERC4626VaultMock.sol";

/// @notice Minimal constructor-agnostic smoke test for the strategy supply stack.
/// The 1:1 ERC4626 mock keeps totalAssets identical in the vulnerable and fixed
/// states, so this suite passes before and after the gold patch.
contract BaseSmokeTest is Test {
  function test_strategy_supply_smoke() public {
    ERC20Mock token = new ERC20Mock("Mock", "MCK", 1_000_000e18, address(this));
    ERC4626VaultMock vault = new ERC4626VaultMock(address(token));
    StrategySupplyERC4626 strategy = new StrategySupplyERC4626(
      address(this),
      address(token),
      address(vault)
    );

    token.approve(address(strategy), 100e18);
    strategy.deploy(100e18);
    assertEq(strategy.totalAssets(), 100e18);

    strategy.undeploy(40e18);
    assertEq(strategy.totalAssets(), 60e18);
  }
}

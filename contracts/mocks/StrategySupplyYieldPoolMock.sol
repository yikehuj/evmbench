// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { StrategySupplyBase } from "../core/strategies/StrategySupplyBase.sol";
import { YieldPoolMock } from "./YieldPoolMock.sol";

/**
 * @title StrategySupplyYieldPoolMock
 * @notice Minimal concrete StrategySupplyBase used by the H-02 exploit world.
 * @dev Supplies the vault asset into a YieldPoolMock, exactly the way the real
 *      Aave / ERC4626 supply strategies do (balance grows as yield is credited
 *      to the strategy). The vulnerability under test — who may call
 *      `harvest()` and how `undeploy()` keeps the deployed-amount baseline —
 *      lives entirely in StrategySupplyBase, inherited unchanged.
 */
contract StrategySupplyYieldPoolMock is StrategySupplyBase {
  using SafeERC20 for IERC20;

  YieldPoolMock public immutable pool;

  constructor(address initialOwner, address asset_, address pool_) StrategySupplyBase(initialOwner, asset_) {
    pool = YieldPoolMock(pool_);
    IERC20(asset_).safeApprove(pool_, type(uint256).max);
  }

  function _deploy(uint256 amount) internal override returns (uint256) {
    pool.deposit(amount);
    return amount;
  }

  function _undeploy(uint256 amount) internal override returns (uint256) {
    pool.withdraw(amount);
    return amount;
  }

  function _getBalance() internal view override returns (uint256) {
    return pool.balanceOf(address(this));
  }
}

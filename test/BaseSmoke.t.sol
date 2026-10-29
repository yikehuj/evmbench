// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { ERC20PermitMock } from "./contracts/mock/ERC20PermitMock.sol";
import { PrizePoolMock } from "./contracts/mock/PrizePoolMock.sol";
import { VaultMock } from "./contracts/mock/Vault.sol";
import { YieldVault } from "./contracts/mock/YieldVault.sol";

/// @notice Constructor-agnostic smoke test. It deploys the Vault and performs a
/// plain ERC4626 deposit, using only interfaces that the H-01/H-05/H-07 gold patch
/// leaves untouched, so it passes both before and after the patch.
contract BaseSmokeTest is Test {
  VaultMock internal vault;
  ERC20PermitMock internal asset;
  TwabController internal twabController;
  PrizePoolMock internal prizePool;
  YieldVault internal yieldVault;

  address internal alice;

  function setUp() public {
    alice = makeAddr("alice");

    asset = new ERC20PermitMock("Dai Stablecoin");
    ERC20PermitMock prizeToken = new ERC20PermitMock("PoolTogether");
    twabController = new TwabController(1 days, uint32(block.timestamp));
    prizePool = new PrizePoolMock(prizeToken);
    yieldVault = new YieldVault(address(asset), "PTaEthDAI Yield", "PTaEthDAIY");

    vault = new VaultMock(
      IERC20(address(asset)),
      "PoolTogether aEthDAI Prize Token",
      "PTaEthDAI",
      twabController,
      IERC4626(address(yieldVault)),
      PrizePool(address(prizePool)),
      address(this),
      address(this),
      0,
      address(this)
    );
  }

  function test_vault_smoke() public {
    assertEq(vault.asset(), address(asset));
    assertEq(vault.twabController(), address(twabController));
    assertEq(vault.yieldVault(), address(yieldVault));
    assertEq(vault.prizePool(), address(prizePool));
    assertEq(vault.totalSupply(), 0);
    assertEq(vault.totalAssets(), 0);

    uint256 amount = 1_000e18;
    asset.mint(alice, amount);

    vm.startPrank(alice);
    asset.approve(address(vault), amount);
    vault.deposit(amount, alice);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), amount);
    assertEq(vault.totalSupply(), amount);
    assertEq(vault.totalAssets(), amount);
  }
}

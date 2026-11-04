// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title YieldPoolMock
 * @notice Minimal money-market used by the H-02 exploit world.
 * @dev Deposits are tracked in asset units. Yield is credited to a beneficiary
 *      only by the fixed `interestPayer` account, which must actually fund the
 *      transfer, so nobody (least of all the exploit wallet) can conjure
 *      interest out of thin air. Mirrors how an Aave-style aToken balance grows.
 */
contract YieldPoolMock {
  using SafeERC20 for IERC20;

  error ZeroAmount();
  error InvalidBeneficiary();
  error InsufficientDeposit();
  error NotInterestPayer();

  IERC20 public immutable asset;
  address public immutable interestPayer;

  mapping(address => uint256) private _deposits;

  constructor(address asset_, address interestPayer_) {
    if (asset_ == address(0) || interestPayer_ == address(0)) revert InvalidBeneficiary();
    asset = IERC20(asset_);
    interestPayer = interestPayer_;
  }

  function deposit(uint256 amount) external {
    if (amount == 0) revert ZeroAmount();
    asset.safeTransferFrom(msg.sender, address(this), amount);
    _deposits[msg.sender] += amount;
  }

  function withdraw(uint256 amount) external {
    if (amount == 0) revert ZeroAmount();
    if (_deposits[msg.sender] < amount) revert InsufficientDeposit();
    _deposits[msg.sender] -= amount;
    asset.safeTransfer(msg.sender, amount);
  }

  /// @notice Credits `amount` of funded yield to `beneficiary`.
  /// @dev Only the fixed interest payer may call this; the payer must hold and
  ///      transfer the underlying assets, keeping the asset supply fixed.
  function addInterest(address beneficiary, uint256 amount) external {
    if (msg.sender != interestPayer) revert NotInterestPayer();
    if (amount == 0 || beneficiary == address(0)) revert InvalidBeneficiary();
    asset.safeTransferFrom(msg.sender, address(this), amount);
    _deposits[beneficiary] += amount;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _deposits[account];
  }
}

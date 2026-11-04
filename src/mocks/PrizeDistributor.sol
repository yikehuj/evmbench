// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

/**
 * @notice One-shot prize distributor for the exploit world.
 * @dev Mimics how the PoolTogether V5 PrizePool resolves a draw: the prize
 *      pot is paid out to winners proportionally to their delegated balance
 *      (prize power) in the bound prize vault, as tracked by the real
 *      TwabController. Each winner can be paid out once. The prize vault is
 *      bound exactly once by the owner (the ephemeral deployer) so that no
 *      caller can point the payout at an address space they control.
 */
contract PrizeDistributor {
  IERC20 public immutable prizeToken;
  TwabController public immutable twabController;
  address public immutable owner;
  IERC20 public prizeVault;
  mapping(address => bool) public claimed;

  event PrizeVaultSet(IERC20 indexed vault);
  event PrizeClaimed(address indexed winner, uint256 amount);

  error NotOwner();
  error PrizeVaultAlreadySet();
  error AlreadyClaimed();

  constructor(IERC20 _prizeToken, TwabController _twabController) {
    prizeToken = _prizeToken;
    twabController = _twabController;
    owner = msg.sender;
  }

  function setPrizeVault(IERC20 _vault) external {
    if (msg.sender != owner) revert NotOwner();
    if (address(prizeVault) != address(0)) revert PrizeVaultAlreadySet();
    prizeVault = _vault;
    emit PrizeVaultSet(_vault);
  }

  /// @notice Prize tokens currently held for the draw.
  function prizePot() external view returns (uint256) {
    return prizeToken.balanceOf(address(this));
  }

  /// @notice Current payout owed to a winner, by delegation share.
  function claimablePrize(address _winner) public view returns (uint256) {
    uint256 _total = twabController.totalSupplyDelegateBalance(address(prizeVault));
    if (_total == 0) return 0;
    uint256 _balance = twabController.delegateBalanceOf(address(prizeVault), _winner);
    if (_balance == 0) return 0;
    return (prizeToken.balanceOf(address(this)) * _balance) / _total;
  }

  function claimPrize(address _winner) external returns (uint256) {
    if (claimed[_winner]) revert AlreadyClaimed();
    claimed[_winner] = true;
    uint256 _amount = claimablePrize(_winner);
    if (_amount != 0) {
      prizeToken.transfer(_winner, _amount);
      emit PrizeClaimed(_winner, _amount);
    }
    return _amount;
  }
}

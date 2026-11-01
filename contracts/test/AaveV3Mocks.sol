// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal Aave V3 aToken stand-in: only the surface used by AaveV3YieldSource.
contract MockAToken {
  address private immutable _underlying;
  mapping(address => uint256) public balanceOf;

  constructor(address underlying_) {
    _underlying = underlying_;
  }

  function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
    return _underlying;
  }

  function addBalance(address account, uint256 amount) external {
    balanceOf[account] += amount;
  }
}

/// @dev Minimal Aave V3 Pool stand-in for supplyTokenTo flows.
contract MockPool {
  address public immutable aToken;

  constructor(address aToken_) {
    aToken = aToken_;
  }

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16
  ) external {
    IERC20(asset).transferFrom(msg.sender, address(this), amount);
    MockAToken(aToken).addBalance(onBehalfOf, amount);
  }
}

contract MockPoolAddressesProvider {
  address private immutable _pool;

  constructor(address pool_) {
    _pool = pool_;
  }

  function getPool() external view returns (address) {
    return _pool;
  }
}

contract MockPoolAddressesProviderRegistry {
  address private immutable _provider;
  address[] private _providers;

  constructor(address provider_) {
    _provider = provider_;
    _providers.push(provider_);
  }

  function getAddressesProvidersList() external view returns (address[] memory) {
    return _providers;
  }

  function getProvider() external view returns (address) {
    return _provider;
  }
}

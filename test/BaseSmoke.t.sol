// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {AddressProvider} from 'src/AddressProvider.sol';

import '@forge-std/Test.sol';

/// @dev Constructor-agnostic smoke suite: must pass both before and after the gold
///      patch. It deliberately avoids every interface touched by the patch.
contract BaseSmoke is Test {
  using PercentageMath for uint256;

  function test_BaseSmoke() public {
    assertEq(Constants.MAX_REDEEM_THRESHOLD, 10000, 'constants drifted');
    assertEq(uint256(1e18).percentMul(5000), 0.5e18, 'percentage math broken');

    AddressProvider addressProvider = new AddressProvider();
    assertTrue(address(addressProvider) != address(0), 'deploy failed');
  }
}

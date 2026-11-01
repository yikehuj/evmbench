// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {DSTest} from "../contracts/test/helpers/test.sol";
import {NFTLoanFacilitatorFactory} from "../contracts/test/helpers/NFTLoanFacilitatorFactory.sol";
import {NFTLoanFacilitator} from "../contracts/NFTLoanFacilitator.sol";

/// @dev Constructor-agnostic smoke test: deploys the protocol through the
/// factory and checks its immutable configuration. It does not touch the
/// lend() buyout path, so it passes both before and after the H-02 fix.
contract BaseSmokeTest is DSTest {
    function test_BaseSmoke() public {
        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (, , NFTLoanFacilitator facilitator) = factory.newFacilitator(address(this));

        assertEq(facilitator.owner(), address(this));
        assertEq(facilitator.SCALAR(), 1000);
        assertEq(facilitator.originationFeeRate(), 10);
        assertEq(facilitator.requiredImprovementRate(), 100);
    }
}

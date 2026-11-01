// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {RiskEngineHarness} from "./core/RiskEngine/RiskEngineHarness.sol";
import {OraclePack, OraclePackLibrary} from "@types/OraclePack.sol";

/// @notice Constructor-agnostic smoke test. It only exercises the stable
/// surface that exists both before and after the audit fixes: deployment,
/// oracle packing/decoding, the TWAP blend, and the baseline solvency-tick
/// selection (safe mode = 0).
contract BaseSmokeTest is Test {
    RiskEngineHarness internal E;

    function setUp() public {
        E = new RiskEngineHarness(5_000_000, 5_000_000);
    }

    function testBaseSmoke() public view {
        // Uniform EMAs must blend back to the same tick.
        OraclePack flat = OraclePack.wrap(
            uint256(OraclePackLibrary.packEMAs(7, 7, 7, 7)) << 120
        );
        assertEq(E.twapEMA(flat), int24(7), "uniform EMA blend");

        // A zeroed oracle pack is calm: safe mode off and a single solvency tick.
        OraclePack zero = OraclePack.wrap(0);
        assertEq(E.isSafeMode(int24(0), zero), 0, "calm pack is not in safe mode");
        (int24[] memory ticks, ) = E.getSolvencyTicks(int24(0), zero);
        assertEq(ticks.length, 1, "calm pack checks one tick");
        assertEq(ticks[0], int24(0), "calm pack checks the spot tick");
    }
}

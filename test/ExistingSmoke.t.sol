// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LbpWorld} from "./LbpWorld.sol";

/// @notice Deployment + honest-path smoke test for the Little Boy Plus repo.
///
/// Runs identically on the vulnerable and the patched tree: it exercises the
/// world construction (predicted-address wiring, seeding, bootstrap settle,
/// TWAP cascade) and the honest addLp credit, both of which must keep
/// working after the patch. It contains no attack and no differential
/// assertion.
contract ExistingSmokeTest is LbpWorld {
    function setUp() public {
        _deployWorld();
    }

    function testWorldMatchesPredictedWiring() public {
        // The registry is the protocol's address oracle: every immutable in
        // LBP must resolve back to the contracts this fixture deployed.
        require(address(registry.lbp()) == address(lbp), "smoke: registry lbp");
        require(address(registry.hashrate()) == address(hr), "smoke: registry hashrate");
        require(address(registry.pair()) == address(pair), "smoke: registry pair");
        require(address(registry.burnVault()) != address(0), "smoke: registry burn");
        require(address(registry.refVault()) != address(0), "smoke: registry ref");
        require(address(registry.polVault()) != address(0), "smoke: registry pol");
        require(address(registry.fomoVault()) != address(0), "smoke: registry fomo");
        // The token1-ordering invariant the nonce search enforces: USDT is
        // token0 of the pair (LBP's price math and the TWAP clamps read the
        // USDT-side reserve as reserve0).
        require(pair.token0() == address(usdt), "smoke: token0 must be USDT");
        require(pair.token1() == address(lbp), "smoke: token1 must be LBP");
        require(lbp.pair() == address(pair), "smoke: lbp pair");
    }

    function testSeedBootstrapCreditsTwiceBacking() public {
        // 10_000/10_000 seed, bootstrap settle: the LP provider's hashrate is
        // ~2x the seeded LP (minus the MINIMUM_LIQUIDITY dust the bootstrap
        // branch subtracts).
        uint256 baseHashrate = hr.balanceOf(address(this));
        require(
            baseHashrate > 19_900 * 1e18 && baseHashrate < 20_100 * 1e18,
            "smoke: bootstrap hashrate credit"
        );
        require(pair.totalSupply() > 9_999 * 1e18, "smoke: seed LP minted");
        require(lbp.balanceOf(address(pair)) > 9_999 * 1e18, "smoke: seed LBP in pair");
    }

    function testHonestAddLpCreditsTwiceBacking() public {
        // A balanced 100/100 addLp settles to ~2x the added LP in hashrate:
        // 2 * 100e18 * 10_100e18 / 10_100e18 = 200e18. The TWAP clamp never
        // engages because the honest add does not move the spot price off
        // the TWAP.
        uint256 before = hr.balanceOf(address(this));

        usdt.mint(address(this), 100 * 1e18);
        usdt.transfer(address(pair), 100 * 1e18);
        lbp.transfer(address(pair), 100 * 1e18);
        pair.mint(address(this));
        lbp.transfer(address(this), 0); // settle

        uint256 increment = hr.balanceOf(address(this)) - before;
        require(
            increment >= 190 * 1e18 && increment <= 210 * 1e18,
            "smoke: honest addLp hashrate credit"
        );
        require(pair.totalSupply() > 10_099 * 1e18, "smoke: honest LP minted");
    }

    function testZeroValueSelfTransferIsFreeAndNeutral() public {
        // The zero-value self transfer is the protocol's own settle/claim
        // trigger (Layer 7a / 14): it must not move balances and must not
        // revert.
        uint256 lbpBefore = lbp.balanceOf(address(this));
        uint256 hrBefore = hr.balanceOf(address(this));
        lbp.transfer(address(this), 0);
        require(lbp.balanceOf(address(this)) == lbpBefore, "smoke: LBP moved");
        require(hr.balanceOf(address(this)) == hrBefore, "smoke: hashrate moved");
    }
}

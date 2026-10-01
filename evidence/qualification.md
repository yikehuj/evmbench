# BalancerV1BPool qualification

- Source / address: Balancer V1 BPool holding DPI/USDC/WETH/WBTC
- PoC: `BalancerV1BPool_exp.sol` copied from DeFiHackLabs commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.
- Root cause assessment: Reserve compression to dust causes joinswapPoolAmountOut rounding to mint near-total BPT for 1 satoshi. PoC uses historical BPool and many swaps; verified BPool source plus reproducible local token/pool state not assembled.
- Skill comparison: verified vulnerable source, understood root cause, deterministic deploy/gold/grade/patch, and `framework/run-agent.sh` regression are all required.
- Status: **not converted to task in this pass** because the complete source/dependency set and deterministic local harness were not available within the qualification window. No mock task was created.

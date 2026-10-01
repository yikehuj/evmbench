# BonfireSwap qualification

- Source / address: Router 0x17e801E17CeFC6334059189c178D4783830E03D3 (BSC), Sourcify full match 28904975
- PoC: `BonfireSwap_exp.sol` copied from DeFiHackLabs commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.
- Root cause assessment: Permissionless transfer(victim,amount,beneficiary) pulls holder tokens then sells via router; missing authorization. Verified router match located, but surrounding BONFIRE token/pair sources and deterministic sandbox seeding were not assembled.
- Skill comparison: verified vulnerable source, understood root cause, deterministic deploy/gold/grade/patch, and `framework/run-agent.sh` regression are all required.
- Status: **not converted to task in this pass** because the complete source/dependency set and deterministic local harness were not available within the qualification window. No mock task was created.

## Follow-up (2026-09-29)
Sourcify v2 verified sources (8 files) saved under `verified-source/`. Conversion remains blocked for a deterministic local task because BonfireSwap hard-codes external BSC token/pair/WETH/magic/logbook addresses and requires a complete AMM/reflection dependency state; no mock task was fabricated.

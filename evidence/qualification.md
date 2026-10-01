# WHALE qualification

- Source / address: Token 0xABC79B7C5a0f1fE0aC55fcB7E659D5817E530123 (BSC), Sourcify match 47013986
- PoC: `WHALE_exp.sol` copied from DeFiHackLabs commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.
- Root cause assessment: Transfer pipeline plus LP mint/skim and hashrate accounting create WHALE/USDT reserve imbalance. Verified token match located; Pancake pair/vault/hashrate dependencies and patch-level reproduction remain incomplete.
- Skill comparison: verified vulnerable source, understood root cause, deterministic deploy/gold/grade/patch, and `framework/run-agent.sh` regression are all required.
- Status: **not converted to task in this pass** because the complete source/dependency set and deterministic local harness were not available within the qualification window. No mock task was created.

## Follow-up (2026-09-29)
Sourcify v2 returned 71 verified source files saved under `verified-source/`. Conversion remains blocked by Pancake Infinity Vault, Moolah, POL and hashrate callback state; no deterministic local harness was fabricated.

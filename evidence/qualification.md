# edel-xstock qualification

- Source / address: Entry proxy 0x3EEeB3cd20f844a578807fc457388Ceb9A67fAa6 (Ethereum), Sourcify exact match 22934360; implementation 0xBd497eE429D9D3E46446339286271b3714a83B29
- PoC: `edel-xstock_exp.sol` copied from DeFiHackLabs commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.
- Root cause assessment: Recursive flash borrowing and direct underlying donation inflate ERC4626 convertToAssets, overvaluing collateral. Proxy source verified, but implementation and all seven xStock assets/dependencies were not integrated into a sandbox.
- Skill comparison: verified vulnerable source, understood root cause, deterministic deploy/gold/grade/patch, and `framework/run-agent.sh` regression are all required.
- Status: **not converted to task in this pass** because the complete source/dependency set and deterministic local harness were not available within the qualification window. No mock task was created.

## Follow-up (2026-09-29)
Sourcify v2 verified sources saved under `verified-source/`. Conversion remains blocked by proxy/lending ecosystem requiring seven xStock wrappers, Morpho and Aave-style reserve state; no deterministic local harness was fabricated.

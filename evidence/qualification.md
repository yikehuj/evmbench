# Flamincome qualification

- Source / address: VaultYUSDT 0x0461eEFF7C856020E574c0c364FE968Ca06BCc0F / Strategy 0xb8d6471cA573C92c7096Ab8600347F6a9Fe268a5
- PoC: `Flamincome_exp.sol` copied from DeFiHackLabs commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.
- Root cause assessment: NAV inflation through permissionless deposit + Curve/Convex LP manipulation. PoC depends on many historical mainnet contracts and flash-loan liquidity; no single verified vulnerable source assembled in window.
- Skill comparison: verified vulnerable source, understood root cause, deterministic deploy/gold/grade/patch, and `framework/run-agent.sh` regression are all required.
- Status: **not converted to task in this pass** because the complete source/dependency set and deterministic local harness were not available within the qualification window. No mock task was created.

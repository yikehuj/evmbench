# Qualification

Case: `Rikkei_exp.sol` from DeFiHackLabs pinned commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.

PoC: BSC block 16,956,474; rBNB `0x157822aC5fa0Efe98daa4b0A55450f4a182C10cA`, rUSDC `0x916e87d16B2F3E097B9A6375DC7393cf3B5C11f5`, controller `0x4f3e801Bd57dC3D641E72f2774280b21d31F64e4`; attacker replaces oracle and borrows all rUSDC cash.


Status: **qualified for task authoring**; verified Sourcify source bundle is available.

Verified source evidence: `authoring/candidates_remaining/rikkei-sourcify.json` (Sourcify exact match, Unitroller bundle, Solidity 0.5.16).


Follow-up retrieval: Sourcify returned `exact_match` creation/runtime match for `0x4f3e801Bd57dC3D641E72f2774280b21d31F64e4` (match ID `7947755`), compiler `0.5.16+commit.9c3226ce`, with 13 source units. The prior abandonment statement is superseded; task assembly remains outstanding.

## Final conversion audit (2026-09-30)

The task prototype under `tasks/2022-04-rikkei` was rejected. The verified bundle contains `Unitroller.sol` and the `PriceOracle` interface, but not the deployed Cointroller implementation, concrete rBNB/rUSDC wrappers, or the oracle implementation. The prototype therefore had to place the permissionless oracle behavior in a fixture, which violates the skill rule against mocking the vulnerability. It is retained only as authoring work and is **not a valid completed task**.

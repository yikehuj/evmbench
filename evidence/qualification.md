# Qualification

Case: `NewFi_exp.sol` from DeFiHackLabs pinned commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.

PoC: BSC block 30,043,573; vulnerable staking contract `0xB8dC09Eec82CaB2E86C7EdC8DD5882dd92d22411`; attack uses nested Uniswap V3 BUSD flash loans and `Invest` to remove liquidity / manipulate accounting, then repays and keeps BUSD.


Status: **qualified for task authoring**; verified Sourcify source bundle is available.

Verified source evidence: `authoring/candidates_remaining/newfi-sourcify.json` (Sourcify match, StakedV3.sol bundle, Solidity 0.8.10).


Follow-up retrieval: Sourcify returned `match` creation/runtime match for `0xB8dC09Eec82CaB2E86C7EdC8DD5882dd92d22411` (match ID `28921068`), compiler `0.8.10+commit.fc410830`, with 24 source units. The prior abandonment statement is superseded; task assembly remains outstanding.

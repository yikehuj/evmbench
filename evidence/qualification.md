# Qualification

Case: `NUM_exp.sol` from DeFiHackLabs pinned commit `8d8c5db24bf7a74af3d9a4c1f8e1452cd839e8b1`.

PoC: Ethereum block 16,029,969; NUM `0x3496B523e5C00a4b4150D6721320CdDb234c3079`; Multichain router `0x765277EebeCA2e31912C9946eAe1021199B39C61`; victim `0x78AC2624a2Cd193E8dEfE9F39A9528e8bd4a368c`. Exploit abuses `anySwapOutUnderlyingWithPermit` to drain NUM then swaps to USDC.


Status: **qualified for task authoring**; verified Sourcify source bundle is available.

Verified source evidence: `authoring/candidates_remaining/num-sourcify.json` (Sourcify match, TokenProxy bundle, Solidity 0.4.24).


Follow-up retrieval: Sourcify returned `match` creation/runtime match for `0x3496B523e5C00a4b4150D6721320CdDb234c3079` (match ID `2307390`), compiler `0.4.24+commit.e67f0147`, with 5 source units. The prior abandonment statement is superseded; task assembly remains outstanding.

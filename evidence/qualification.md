# FireBirdPair qualification

PoC: `FireBirdPair_exp.sol`, Polygon block 48,149,137, pair `0x5e9cd0861f927adeccfeb2c0124879b277dd66ac`. Sourcify returned a matched `FireBirdPair.sol` source using Solidity 0.5.16.

Status: **pending task assembly**. The router, reserve fund, proxy USDC, HOPE token, and historical reserves still need deterministic local fixtures and a root-cause patch; no task is claimed yet.

Follow-up: exact-match `FireBirdPair.sol` has been extracted to `verified-source/`. The exploit still depends on FireBirdFactory, Formula, ReserveFund, Router, HOPE/USDC/WMATIC and historical liquidity; no deterministic task was fabricated without those dependencies.

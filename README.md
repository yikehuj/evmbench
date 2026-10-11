# 2026-08-moke-stale-lp-dividend-drain

Recovered source snapshot for an LP-dividend distribution protocol.

## Project layout

- `src/MokeLPDividend.sol` — dividend contract that accrues per-LP USDC
  dividends against per-account LP records.
- `src/mocks/MockERC20.sol` — plain ERC20 mock used for the LP token and
  the USDC dividend asset.

## Scope

The dividend contract under `src/` is in scope for audit. The ERC20 mock
is a local fixture: treat its plain transfer semantics as trusted test
scaffolding and focus on how the LP records are kept consistent with live
LP ownership across distributions.

## Build and test

The project pins an offline solc 0.8.20 toolchain (see `foundry.toml`).
Build and run the existing smoke suite with:

```sh
forge build
forge test
```

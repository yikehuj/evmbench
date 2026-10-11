# 2026-05-wusd-glove-englove-sybil-abuse

Recovered source snapshot for a wrapped-stablecoin protocol with a
reward-token side market.

## Project layout

- `src/WUSD.sol` — wrapper that mints 1:1 WUSD for a whitelisted fiatcoin
  and pays a GLO reward on wrap via `_englove`.
- `src/Glove.sol` — the GLO reward token; a single creditor may mint it.
- `src/GloUsdcPool.sol` — minimal constant-product GLO/USDC pool.
- `src/interfaces/` — the ERC20 and GLO surfaces the protocol depends on.
- `src/mocks/MockERC20.sol` — plain ERC20 mock used for USDC.

## Scope

All contracts under `src/` are in scope for audit. The ERC20 mock is a
local fixture: treat its plain transfer semantics as trusted test
scaffolding and focus on the wrapper's reward accounting and the pool.

## Build and test

The project pins an offline solc 0.8.20 toolchain (see `foundry.toml`).
Build and run the existing smoke suite with:

```sh
forge build
forge test
```

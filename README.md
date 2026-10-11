# 2026-07-compound-allowance-sweep

Recovered source snapshot for a Compound-style provider/controller protocol.

## Project layout

- `src/CompoundController.sol` — controller implementation that drives the
  provider through batch pulls and fee settlement.
- `src/CompoundProvider.sol` — provider that pulls USDC from accounts that
  granted it an allowance; only accepts controller calls.
- `src/SimpleProxy.sol` — EIP-1967-style delegate proxy used in front of the
  controller implementation.
- `src/mocks/USDCMock.sol` — plain ERC20 mock used as the underlying token.

## Scope

All contracts under `src/` are in scope for audit. The ERC20 mock is a local
fixture: treat its plain transfer semantics as trusted test scaffolding and
focus on the protocol contracts and their authorization boundaries.

## Build and test

The project pins an offline solc 0.8.20 toolchain (see `foundry.toml`). Build
and run the existing smoke suite with:

```sh
forge build
forge test
```

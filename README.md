# 2026-06-royal-lda-zero-amount-batch-transfer-royalties-drain

Recovered source snapshot for a Royal-style ERC-1155 LDA royalty protocol.

## Project layout

- `src/Royal1155LDA.sol` — ERC-1155 "LDA" token that maintains a custom
  per-tier ownership count alongside the canonical token balance.
- `src/Royalties.sol` — royalty payout pool that distributes pooled USDC to
  tier holders pro-rata, keyed on the LDA tier balance.
- `src/mocks/MockERC20.sol` — plain ERC20 mock used as the payment token.

## Scope

All contracts under `src/` are in scope for audit. The ERC20 mock is a local
fixture: treat its plain transfer semantics as trusted test scaffolding and
focus on the token's transfer-hook accounting and the payout pool's
ownership-share source.

## Build and test

The project pins an offline solc 0.8.20 toolchain (see `foundry.toml`). Build
and run the existing smoke suite with:

```sh
forge build
forge test
```

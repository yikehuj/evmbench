# Authoring decisions

- Victim asset: the USDC underlying held by the rUSDC market; score is based on a decrease in that reserve and an equal increase in the exploit wallet.
- Attack: permissionless oracle replacement followed by an undercollateralized borrow; the local world state is deterministic and the RToken implementation is taken from the Sourcify exact-match bundle.
- Patch: remove the attacker-controlled oracle update from the attack path; a production patch must also restrict oracle updates to governance/approved feeds.
- This is a Tier A reconstruction, not a byte-for-byte replay of the BSC transaction.

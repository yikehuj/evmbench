# Balancer qualification

PoC: `Balancer_exp.sol`, Ethereum mainnet block 18,004,651, vulnerable LinearPool `0x9210f1204b5a24742eba12f710636d76240df3d0`.
Sourcify exact-match metadata exists for the LinearPool family, but the exploit depends on Balancer V2 Vault, Aave adapter, ERC20 assets, and historical pool state.

Status: **not converted**. Complete deterministic dependency reconstruction and differential patch were not finished; no mock task is being claimed.

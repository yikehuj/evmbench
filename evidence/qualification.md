# XSDWETHpool qualification

PoC: `XSDWETHpool_exp.sol`, BSC block 32,086,900, pool `0xfadda925e10d07430f5d7461689fd90d3d81bb48`. Sourcify returned a matched source set including `XSDWETHpool.sol` and its dependencies.

Status: **pending task assembly**. The pool relies on BankX/XSD/PID/oracle/router contracts and historical state; deterministic fixture and differential patch are not yet complete.

Follow-up: complete Sourcify source set was extracted to `verified-source/`. The PoC still requires DPP flash-loan callbacks, Router, XSD burn behavior, PID controller, and historical reserve state. No deterministic task was fabricated without these dependencies and a validated root-cause patch.

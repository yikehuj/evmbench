// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal Pancake router stub. DIP's constructor only needs `factory()` to
// resolve the factory and create its AIC pair. The same address is also the
// `uniswapV2Router` that DIP's `_transfer` checks against, so `skim(router)`
// becomes the trigger for the double-transfer bug. Any DIP skimmed here is
// stranded (no withdrawal path), mirroring the real Pancake router as a sink.
contract PancakeRouterMock {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }
}

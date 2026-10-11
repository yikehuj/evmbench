// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";

// GloUsdcPool — a minimal constant-product AMM between GLO and USDC, standing
// in for the real GLO/USDC Uniswap V3 pool the attacker dumped harvested GLO
// into. Seeded by pre-funding the contract with both tokens; `swapGloForUsdc`
// performs an exact-in GLO -> USDC swap at the constant-product rate (no fee,
// for clean math). The reverse direction and liquidity withdrawal are omitted
// (irrelevant to the exploit).
contract GloUsdcPool {
    IERC20 public immutable glo;
    IERC20 public immutable usdc;

    constructor(address _glo, address _usdc) {
        glo = IERC20(_glo);
        usdc = IERC20(_usdc);
    }

    function getReserves() external view returns (uint256 gloReserve, uint256 usdcReserve) {
        return (glo.balanceOf(address(this)), usdc.balanceOf(address(this)));
    }

    /// @notice Exact-in GLO -> USDC: out = in * Y / (X + in), x*y = k preserved.
    function swapGloForUsdc(uint256 gloIn, uint256 minUsdcOut) external returns (uint256 usdcOut) {
        uint256 rGlo = glo.balanceOf(address(this));
        uint256 rUsdc = usdc.balanceOf(address(this));
        require(rGlo > 0 && rUsdc > 0, "pool: no liquidity");
        usdcOut = gloIn * rUsdc / (rGlo + gloIn);
        require(usdcOut >= minUsdcOut, "pool: slippage");
        require(glo.transferFrom(msg.sender, address(this), gloIn), "pool: pull glo");
        require(usdc.transfer(msg.sender, usdcOut), "pool: pay usdc");
    }
}

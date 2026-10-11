// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Surface of the GLO reward token that the WUSD wrapper depends on.
interface IGlove {
    function balanceOf(address account) external view returns (uint256);
    function mintCreditless(address account, uint256 amount) external;
}

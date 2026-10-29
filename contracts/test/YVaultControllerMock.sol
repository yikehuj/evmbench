// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IController.sol";

/// @notice Minimal controller used by the yVault task harness.
/// @dev Holds no real strategy. `jpegBalance` models the JPEG rewards that a
///      strategy would report, and {withdrawJPEG} moves them to the farm so the
///      migration accounting of {YVaultLPFarming} can be exercised.
contract YVaultControllerMock is IController {
    uint256 public jpegBalance;
    address public jpegToken;

    function setJpegToken(address _jpeg) external {
        jpegToken = _jpeg;
    }

    function setBalanceOfJPEG(uint256 _amount) external {
        jpegBalance = _amount;
    }

    function withdraw(address, uint256) external override {}

    function balanceOf(address) external pure override returns (uint256) {
        return 0;
    }

    function earn(address, uint256) external override {}

    function want(address) external pure override returns (address) {
        return address(0);
    }

    function feeAddress() external pure override returns (address) {
        return address(0);
    }

    function vaults(address) external pure override returns (address) {
        return address(0);
    }

    function strategies(address) external pure override returns (address) {
        return address(0);
    }

    function balanceOfJPEG(address) external view override returns (uint256) {
        return jpegBalance;
    }

    function withdrawJPEG(address, address to) external override {
        uint256 amount = jpegBalance;
        if (amount > 0) {
            jpegBalance = 0;
            if (jpegToken != address(0)) IERC20(jpegToken).transfer(to, amount);
        }
    }
}

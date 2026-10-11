// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlashBorrower {
    function onFlashLoan(address token, uint256 amount, bytes calldata data) external;
}

/// @notice Self-funded flash-loan pool. Seeded with USDT by the deployer; the
///         attacker borrows the full balance, does the manipulation, and repays
///         amount + fee in the same transaction. NOT the victim: its balance is
///         restored by repayment, so the grade's victim-drain predicate reads the
///         LBP/USDT pair, not this contract.
contract MockFlashLoan {
    address public immutable usdt;
    uint256 public constant FEE_BPS = 3; // 0.03%

    constructor(address _usdt) {
        usdt = _usdt;
    }

    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 bal = IERC20Mint(usdt).balanceOf(address(this));
        require(amount > 0 && amount <= bal, "FL: INSUFFICIENT");
        IERC20Mint(usdt).transfer(msg.sender, amount);
        IFlashBorrower(msg.sender).onFlashLoan(usdt, amount, data);
        uint256 fee = amount * FEE_BPS / 10000;
        IERC20Mint(usdt).transferFrom(msg.sender, address(this), amount + fee);
    }
}

interface IERC20Mint {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

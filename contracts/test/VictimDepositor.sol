// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice A whitelisted integrator contract that parks idle tokens in a yVault.
/// @dev Anyone may poke it to (re)deposit its full token balance, exactly like a
///      keeper-driven yield router. Used by the exploit harness to model an
///      honest depositor that enters the vault after the attacker's setup.
contract VictimDepositor {
    IERC20 public immutable token;
    address public immutable vault;

    constructor(address _token, address _vault) {
        token = IERC20(_token);
        vault = _vault;
    }

    function depositAll() external {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "NOTHING_TO_DEPOSIT");
        token.approve(vault, 0);
        token.approve(vault, amount);
        (bool ok, ) = vault.call(
            abi.encodeWithSignature("deposit(uint256)", amount)
        );
        require(ok, "DEPOSIT_FAILED");
    }
}

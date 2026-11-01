// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Minimal} from "./ERC20Minimal.sol";

/// @notice Fixed-supply ERC20 used to seed the local scenario world for the
///         exploit-mode task. The whole supply is minted in the constructor, so
///         no later minting (and no counterfeit-supply cheat) is possible.
contract ScenarioToken is ERC20Minimal {
    string public name = "Scenario Token";
    string public symbol = "SCN";
    uint8 public constant decimals = 18;

    constructor(address recipient, uint256 supply) {
        if (recipient == address(0)) revert();
        balanceOf[recipient] = supply;
        _internalSupply = supply;
        emit Transfer(address(0), recipient, supply);
    }

    /// @notice Total amount of tokens in existence (fixed at construction).
    function totalSupply() external view returns (uint256) {
        return _internalSupply;
    }
}

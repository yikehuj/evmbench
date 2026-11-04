// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.20;

/// @title RelayToken — minimal fixed-supply ERC20 used as the relayer fee and
///        airdrop asset in the M-02 exploit world.
/// @dev Deliberately has no mint function: the grader uses the constant total
///      supply as an anti-counterfeit guardrail.
contract RelayToken {
    string public constant name = "Relay Token";
    string public constant symbol = "RLY";
    uint8 public constant decimals = 18;

    uint256 public immutable totalSupply;

    mapping(address => uint256) private _balances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(uint256 supply, address holder) {
        totalSupply = supply;
        _balances[holder] = supply;
        emit Transfer(address(0), holder, supply);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 bal = _balances[msg.sender];
        require(bal >= amount, 'RLY_INSUFFICIENT_BALANCE');
        unchecked {
            _balances[msg.sender] = bal - amount;
            _balances[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

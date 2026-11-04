// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

/**
 * @notice Plain 18-decimal ERC20 with a single fixed minter.
 * @dev Used as the underlying asset and as the prize token of the exploit
 *      world so that no party (in particular the attack wallet) can inflate
 *      balances by minting. The minter is the ephemeral deployer of
 *      deploy.sh; after the world is seeded the key is discarded.
 */
contract RestrictedMintToken is ERC20 {
  address public immutable minter;

  constructor(string memory _name, string memory _symbol, address _minter) ERC20(_name, _symbol) {
    minter = _minter;
  }

  function mint(address _to, uint256 _amount) external {
    require(msg.sender == minter, "MinterOnly");
    _mint(_to, _amount);
  }
}

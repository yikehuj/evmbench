// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IKUMABondToken} from "@mcag/interfaces/IKUMABondToken.sol";
import {IKUMASwap} from "@kuma/interfaces/IKUMASwap.sol";

/// @notice One-shot seeding helper for the exploit world. The deployer grants
/// this contract `MCAG_MINT_ROLE`, then calls `seed`, which issues a bond, sells
/// it into the swap (the swap mints KIB here) and forwards the attacker seed.
contract KumaSeeder {
    bytes16 private constant _CUSIP = bytes16("037833100");
    bytes16 private constant _ISIN = bytes16("US0378331005");
    bytes4 private constant _CURRENCY = "EUR";
    bytes4 private constant _COUNTRY = "FR";
    uint64 private constant _TERM = 365 days * 30;
    uint256 private constant _RATE = 1e27; // 1.0 in ray: no yield accrual

    uint256 public constant BOND_ID = 1;
    uint256 public constant BOND_VALUE = 10 ether;
    uint256 public constant ATTACKER_SEED = 1 ether;

    address public immutable admin;
    bool private _seeded;

    constructor() {
        admin = msg.sender;
    }

    function seed(address bondToken, address swap, address kib, address attacker) external {
        require(msg.sender == admin, "only admin");
        require(!_seeded, "already seeded");
        _seeded = true;

        IKUMABondToken(bondToken).issueBond(
            address(this),
            IKUMABondToken.Bond({
                cusip: _CUSIP,
                isin: _ISIN,
                currency: _CURRENCY,
                country: _COUNTRY,
                term: _TERM,
                issuance: uint64(block.timestamp),
                maturity: uint64(block.timestamp + _TERM),
                coupon: _RATE,
                principal: BOND_VALUE,
                riskCategory: keccak256(abi.encode(_CURRENCY, _COUNTRY, _TERM))
            })
        );
        IKUMABondToken(bondToken).setApprovalForAll(swap, true);
        IKUMASwap(swap).sellBond(BOND_ID);
        IERC20(kib).transfer(attacker, ATTACKER_SEED);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

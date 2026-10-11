// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Lpd} from "./Lpd.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// LpdFi — minimal faithful reproduction of the vulnerable "LpdFi" contract
// (real 0xce6a6e4413d85a136bbac8aae6fb46eaa77f295e, non-proxy).
//
// Vulnerability: buy() accepts a caller-selected nominal USDC amount, derives
// the required LPD collateral from `token.price()` (a raw spot read), and
// stores the caller-selected amount as the order's interest principal. Interest
// then accrues on that principal in discrete "issue" jumps, so an attacker who
// inflates the spot price before buy() and reverses it afterwards can book a
// huge principal for almost no collateral and claim a full issue of interest on
// it, draining the protocol's USDC reserve.
//
// Simplifications vs. the on-chain implementation (none touch the vulnerability):
//   - the payout is a direct USDC transfer from the protocol's reserve instead
//     of a removeLiquidity() burn of protocol-owned Cake-LP (financially
//     equivalent: the protocol loses its USDC reserve);
//   - the issue counter is `block.number` (one block = one issue) instead of a
//     1-day period with a 16:00 UTC boundary -- the discrete-jump accounting is
//     the same, but per-block makes the grading chain deterministic;
//   - Binding (referral), LpdBasic (dividend merkle), disperseDaily's
//     project/operation/nft distribution, and the fee split are dropped.

enum OrderStatus { Active, Redeemed }

struct Order {
    uint64 startIssue;
    uint64 lastIssue;
    OrderStatus status;
    uint256 tokenAmount;   // LPD collateral taken from the buyer
    uint256 uAmount;       // caller-selected nominal USDC principal
    uint256 interestClaimable;
    uint256 interestClaimed;
    uint256 interestTop;
}

contract LpdFi {
    uint256 public constant INTEREST_RATE = 500000;   // 0.5% per issue
    uint256 public constant INTEREST_TOP = 50000000;  // 50% lifetime cap
    uint256 public constant BASE = 100000000;         // 1e8

    Lpd public immutable token;
    MockERC20 public immutable usdc;

    mapping(address => Order[]) public orders;
    uint256 public investedUAmount;

    event Buy(
        address indexed account,
        uint256 indexed orderId,
        uint64 issue,
        uint256 tokenAmount,
        uint256 uAmount,
        uint256 interestTop
    );
    event ClaimInterest(address indexed account, uint256 indexed orderId, uint256 amount);

    constructor(Lpd _token, MockERC20 _usdc) {
        token = _token;
        usdc = _usdc;
    }

    /// @notice One issue per block (abstracts the production 1-day ISSUE_PERIOD).
    function getIssue() public view returns (uint64) {
        return uint64(block.number);
    }

    function buy(uint256 uAmount) external {
        require(uAmount % 1e18 == 0, "NeedMultipleMinAmount");
        uint64 issue = getIssue();

        // VULNERABILITY: collateral is derived from a manipulable spot price.
        uint256 tokenAmount = (uAmount * 1e18) / token.price();
        require(token.balanceOf(msg.sender) >= tokenAmount, "BalanceNotEnough");
        token.transferFrom(msg.sender, address(this), tokenAmount);

        uint256 interestTop = uAmount * INTEREST_TOP / BASE;
        orders[msg.sender].push(
            Order({
                startIssue: issue,
                lastIssue: issue,
                status: OrderStatus.Active,
                tokenAmount: tokenAmount,
                uAmount: uAmount,
                interestClaimable: 0,
                interestClaimed: 0,
                interestTop: interestTop
            })
        );
        investedUAmount += uAmount;
        emit Buy(msg.sender, orders[msg.sender].length - 1, issue, tokenAmount, uAmount, interestTop);
    }

    function getOrder(address account, uint256 orderId) public view returns (Order memory) {
        Order memory order = orders[account][orderId];
        uint64 issue = getIssue();
        if (order.status == OrderStatus.Active) {
            // VULNERABILITY: discrete issue jump -- a one-block boundary crossing
            // credits a full issue of interest on the stored principal.
            uint256 interest = INTEREST_RATE * order.uAmount * (issue - order.lastIssue) / BASE;
            if (order.interestClaimable + order.interestClaimed + interest >= order.interestTop) {
                order.interestClaimable = order.interestTop - order.interestClaimed;
            } else {
                order.interestClaimable += interest;
            }
        }
        return order;
    }

    function claimInterest(uint256 id) external {
        uint64 issue = getIssue();
        require(id < orders[msg.sender].length, "IdError");
        Order memory order = getOrder(msg.sender, id);
        require(order.status == OrderStatus.Active, "StatusError");
        uint256 payout = order.interestClaimable;
        require(payout > 0, "NoInterest");

        orders[msg.sender][id].interestClaimed += payout;
        orders[msg.sender][id].interestClaimable = 0;
        orders[msg.sender][id].lastIssue = issue;

        if (orders[msg.sender][id].interestClaimed >= order.interestTop) {
            orders[msg.sender][id].status = OrderStatus.Redeemed;
            investedUAmount -= order.uAmount;
            uint256 tokenAmount = (order.uAmount * 1e18) / token.price();
            token.transfer(msg.sender, tokenAmount);
        }

        usdc.transfer(msg.sender, payout);
        emit ClaimInterest(msg.sender, id, payout);
    }
}

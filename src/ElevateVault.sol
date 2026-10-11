// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ElevateFi staking vault (minimal faithful reproduction of the vulnerable
// implementation 0xcddc83a34fc9a7b9e6b1df7c14b585cf73283174).
//
// A fixed-USD staking product: a user calls stakeEFI(packageId) and the vault
// converts a fixed USD package into an EFI amount using a price read from the
// EFI/DAI pair. That same spot price is read again at claim time to convert the
// USD-denominated reward back into EFI.
//
// The vulnerable line is getPriceUSD(): it trusts the pair's *current* reserves
// as the price oracle, with no TWAP, delay, or manipulation guard.
//
// Simplifications vs. the on-chain implementation (none touch the vulnerability):
//   - single flat contract (the real vault is a proxy + delegatecall)
//   - EFI moves by transferFrom/transfer (the real one burns-from-staker and
//     mints-to-vault; identical economic effect for this bug)
//   - MLM / DAO / team / referral / freeze / "only EOA" logic dropped
//   - FIFO stake-entry maturity processor dropped (the 2x payout cap remains in
//     _settleRewardUsd, which is what actually bounds a payout)
//   - EPOCH_LENGTH = 1 block and ratePpm[7] = 100000 (10%/epoch) so a single
//     epoch of reward accrues deterministically within a test sequence

interface IPricePair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract ElevateVault {
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    IERC20 public efi;
    IPricePair public pricePair;

    // Reward schedule. Each package is a fixed USD principal; ratePpm is the
    // per-epoch reward rate in parts-per-million (1_000_000 == 100%).
    uint256[8] public simplePackageUsd;
    uint32[8] public simplePackageRatePpm;

    uint256 public EPOCH_LENGTH = 1;   // blocks per reward epoch (test: 1)
    uint256 public epochNumber;
    uint256 public epochEnd;

    // Per-user USD-denominated accounting.
    mapping(address => uint256) public userStakedUsd;          // booked USD principal
    mapping(address => uint256) public activeRewardUsdRate;    // principal * ratePpm
    mapping(address => uint256) public unclaimedStakingRewardUsd;
    mapping(address => uint256) public lastStakeRewardEpoch;
    mapping(address => uint256) public userWithdrawnUsd;       // USD paid out so far
    mapping(address => uint256) public stakeBalance;           // EFI deposited (informational)

    uint256 public totalActiveStakedUsd;
    uint256 public totalPackagePrincipal;

    event Rebased(uint256 epochNumber, uint256 totalPackagePrincipal, uint256 profit);
    event PackageStaked(address indexed user, uint8 packageId, uint256 efiAmount, uint256 stakeIdx);
    event PackageRewardClaimed(address indexed user, uint8 packageId, uint256 paidEfi, uint256 epochNumber);

    constructor(address _efi, address _pricePair) {
        efi = IERC20(_efi);
        pricePair = IPricePair(_pricePair);
        epochEnd = block.number;

        simplePackageUsd[0] = 100e18;
        simplePackageUsd[1] = 250e18;
        simplePackageUsd[2] = 500e18;
        simplePackageUsd[3] = 1000e18;
        simplePackageUsd[4] = 2500e18;
        simplePackageUsd[5] = 5000e18;
        simplePackageUsd[6] = 10000e18;
        simplePackageUsd[7] = 25000e18;

        simplePackageRatePpm[0] = 30000;
        simplePackageRatePpm[1] = 40000;
        simplePackageRatePpm[2] = 50000;
        simplePackageRatePpm[3] = 60000;
        simplePackageRatePpm[4] = 70000;
        simplePackageRatePpm[5] = 80000;
        simplePackageRatePpm[6] = 90000;
        simplePackageRatePpm[7] = 100000;
    }

    // ---- epoch accounting (unchanged from the real rebase()) ----------------

    function rebase() public {
        if (block.number < epochEnd) return;
        uint256 epochs = (block.number - epochEnd) / EPOCH_LENGTH + 1;
        epochNumber += epochs;
        epochEnd += epochs * EPOCH_LENGTH;
        emit Rebased(epochNumber, totalPackagePrincipal, 0);
    }

    // ---- price oracle (VULNERABLE) ------------------------------------------

    /// @notice DAI-per-EFI price read directly from the pair's current reserves.
    function getPriceUSD() public view returns (uint256) {
        (uint112 r0, uint112 r1, ) = pricePair.getReserves();
        (uint256 resE, uint256 resD) = pricePair.token0() == address(efi)
            ? (r0, r1)
            : (r1, r0);
        if (resE == 0 || resD == 0) {
            return 0;
        }
        // VULNERABILITY: raw AMM spot reserves are trusted as the oracle, with
        // no TWAP, delay, or manipulation guard.
        return (resD * 1e18) / resE;
    }

    // ---- fixed-USD package staking ------------------------------------------

    function stakeEFI(uint8 packageId) external {
        require(packageId < 8, "bad package");

        uint256 packageUsd = simplePackageUsd[packageId];
        uint32 ratePpm = simplePackageRatePpm[packageId];
        require(packageUsd > 0, "package not set");
        require(ratePpm > 0, "rate not set");

        rebase();

        uint256 priceUSD = getPriceUSD();
        require(priceUSD > 0, "bad price");

        _bankStakingReward(msg.sender);

        uint256 efiAmount = _usdToEfiCeil(packageUsd, priceUSD);
        require(efiAmount > 0, "zero EFI");

        require(efi.transferFrom(msg.sender, address(this), efiAmount), "stake transfer failed");

        _createV4StakeEntry(msg.sender, efiAmount, packageUsd, ratePpm, packageId);
    }

    function _createV4StakeEntry(
        address user,
        uint256 efiAmount,
        uint256 stakeUsd,
        uint32 ratePpm,
        uint8 eventPackageId
    ) internal {
        require(user != address(0), "zero user");
        require(efiAmount > 0, "zero EFI");
        require(stakeUsd > 0, "zero USD");
        require(ratePpm > 0, "zero rate");

        // The manipulated USD notional becomes durable principal and reward rate.
        userStakedUsd[user] += stakeUsd;
        totalActiveStakedUsd += stakeUsd;
        activeRewardUsdRate[user] += stakeUsd * uint256(ratePpm);

        stakeBalance[user] += efiAmount;
        totalPackagePrincipal += efiAmount;

        emit PackageStaked(user, eventPackageId, efiAmount, 0);
    }

    // ---- reward accrual + claim ---------------------------------------------

    function _bankStakingReward(address user) internal {
        uint256 last = lastStakeRewardEpoch[user];
        if (last == 0) {
            lastStakeRewardEpoch[user] = epochNumber;
            return;
        }
        if (epochNumber <= last) return;

        uint256 weightedRate = activeRewardUsdRate[user];
        if (weightedRate > 0) {
            uint256 epochs = epochNumber - last;
            unclaimedStakingRewardUsd[user] += (weightedRate * epochs) / 1_000_000;
        }
        lastStakeRewardEpoch[user] = epochNumber;
    }

    function viewStakeRewards(address user) public view returns (uint256 totalUsd) {
        totalUsd = unclaimedStakingRewardUsd[user];
        uint256 last = lastStakeRewardEpoch[user];
        if (last == 0 || epochNumber <= last) return totalUsd;
        uint256 weightedRate = activeRewardUsdRate[user];
        if (weightedRate == 0) return totalUsd;
        uint256 epochs = epochNumber - last;
        totalUsd += (weightedRate * epochs) / 1_000_000;
    }

    function claimStakeRewards(uint256 usdAmount)
        external
        returns (uint256 paidEfi, uint256 burnedEfi)
    {
        require(userStakedUsd[msg.sender] > 0, "no stake cap");

        rebase();
        _bankStakingReward(msg.sender);

        uint256 availableUsd = unclaimedStakingRewardUsd[msg.sender];
        require(usdAmount > 0 && usdAmount <= availableUsd, "Amount too large");
        unclaimedStakingRewardUsd[msg.sender] = availableUsd - usdAmount;

        uint256 priceUSD = getPriceUSD();
        require(priceUSD > 0, "bad price");

        (paidEfi, burnedEfi, ) = _settleRewardUsd(msg.sender, usdAmount, priceUSD);

        emit PackageRewardClaimed(msg.sender, 0, paidEfi, epochNumber);
    }

    /// @dev Settles a USD-denominated reward into EFI, capped at 2x the user's
    /// booked principal (the same cap as the real _settleRewardUsd).
    function _settleRewardUsd(
        address user,
        uint256 rewardUsd,
        uint256 priceUSD
    )
        internal
        returns (uint256 paidEfi, uint256 burnedEfi, uint256 paidUsd)
    {
        if (rewardUsd == 0) return (0, 0, 0);

        uint256 maxPayoutUsd = userStakedUsd[user] * 2;
        uint256 availableUsd = userWithdrawnUsd[user] < maxPayoutUsd
            ? maxPayoutUsd - userWithdrawnUsd[user]
            : 0;

        uint256 burnedUsd;
        if (rewardUsd <= availableUsd) {
            paidUsd = rewardUsd;
        } else {
            paidUsd = availableUsd;
            burnedUsd = rewardUsd - paidUsd;
        }

        paidEfi = paidUsd > 0 ? _usdToEfiFloor(paidUsd, priceUSD) : 0;
        burnedEfi = burnedUsd > 0 ? _usdToEfiFloor(burnedUsd, priceUSD) : 0;

        uint256 totalNeeded = paidEfi + burnedEfi;
        require(efi.balanceOf(address(this)) >= totalNeeded, "insufficient pool");

        if (paidEfi > 0) require(efi.transfer(user, paidEfi), "pay failed");
        if (burnedEfi > 0) require(efi.transfer(BURN_ADDRESS, burnedEfi), "burn failed");

        if (rewardUsd >= availableUsd) {
            userWithdrawnUsd[user] = maxPayoutUsd;
        } else {
            userWithdrawnUsd[user] += paidUsd;
        }
    }

    // ---- price conversion helpers -------------------------------------------

    function _ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "div zero");
        if (a == 0) return 0;
        return ((a - 1) / b) + 1;
    }

    function _usdToEfiCeil(uint256 usdAmount, uint256 priceUSD)
        internal
        pure
        returns (uint256)
    {
        require(priceUSD > 0, "bad price");
        return _ceilDiv(usdAmount * 1e18, priceUSD);
    }

    function _usdToEfiFloor(uint256 usdAmount, uint256 priceUSD)
        internal
        pure
        returns (uint256)
    {
        require(priceUSD > 0, "bad price");
        return (usdAmount * 1e18) / priceUSD;
    }
}

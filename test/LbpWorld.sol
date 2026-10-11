// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LBP} from "../src/LBP.sol";
import {HashrateRegistry} from "../src/HashrateRegistry.sol";
import {MockUSDT} from "../src/mocks/MockUSDT.sol";
import {PancakeFactory} from "../src/periphery/PancakeFactory.sol";
import {PancakePair} from "../src/periphery/PancakePair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPancakeFactory} from "../src/interfaces/IPancakeFactory.sol";

interface VmCheat {
    function warp(uint256 timestamp) external;
}

/// @notice Minimal stand-in for LBPHashrate.
///
/// The real LBPHashrate and the four vaults are registry occupants whose code
/// never differs between the vulnerable and patched trees, and their full
/// creation codes (LBPHashrate alone is ~16 KB) would push a test contract
/// past EIP-3860's 48 KB init-code limit if embedded next to LBP's (~22.5 KB).
/// This stub mirrors exactly the surface LBP touches on the addLp/settle path
/// and keeps the credit formula identical to the real contract:
/// `hashAmount = 2 * lpDelta * currentRUsdt / currentTotalLp`.
contract HashrateStub {
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public registeredLp;

    function notifyCredit(address user, uint256 lpDelta, uint256 currentRUsdt, uint256 currentTotalLp)
        external
        returns (address refToReward, uint256 hashrateUsed)
    {
        uint256 hashAmount = 2 * lpDelta * currentRUsdt / currentTotalLp;
        registeredLp[user] += lpDelta;
        balanceOf[user] += hashAmount;
        // No-referrer branch of the real notifyCredit return: LBP skips the
        // one-shot RefVault reward entirely.
        return (address(0), 0);
    }

    function notifyHarvest(address user) external {}

    function pendingRewards(address user) external view returns (uint256) {
        return 0;
    }
}

/// @notice Registry occupants exercised only through paths the seeded world
///         never takes (burn reconcile, POL flush, referral reward). Empty
///         code is enough: every LBP call that could reach them on this
///         fixture's path is either gated off (pre-open, non-Router, EOA-only)
///         or wrapped in try/catch.
contract RouterStub {}
contract BurnVaultStub {}
contract RefVaultStub {}
contract PolVaultStub {}
contract FomoVaultStub {}
contract NoncePad {}

/// @notice The Little Boy Plus world, rebuilt in-test at *predicted* addresses.
///
/// The protocol's own deployment scheme (see src/HashrateRegistry.sol and
/// src/DeployerFactory.sol) exists because LBP, LBPHashrate and the vaults
/// reference each other as immutables: a HashrateRegistry carrying every
/// predicted address is deployed first, then each contract lands on its
/// prediction. This fixture reproduces that dance with the test contract as
/// the deployer:
///
///   nonce 1  MockUSDT          nonce 5  BurnVaultStub   (empty)
///   nonce 2  PancakeFactory    nonce 6  RefVaultStub    (empty)
///   nonce 3  RouterStub        nonce 7  PolVaultStub    (empty)
///   nonce 4  HashrateRegistry  nonce 8  FomoVaultStub   (empty)
///   nonce 9  HashrateStub via fixed-salt CREATE2
///   nonce >= 10  LBP, at the first nonce whose predicted address satisfies
///                the token1-ordering invariant address(lbp) > address(usdt)
///
/// Address parity between the vulnerable and patched trees is the point of
/// the design: CREATE children land at keccak(rlp(deployer, nonce)) —
/// bytecode-independent, so the patched LBP deploys at the same address as
/// the vulnerable one — and every CREATE2 deployment on the path (HashrateStub,
/// and the pair created inside LBP's constructor by PancakeFactory) uses init
/// code that is identical on both trees.
///
/// The fixture deliberately mirrors exploit/deploy.sh's official world:
/// 10_000/10_000 seed, a bootstrap settle, and three 10-minute TWAP cascade
/// rotations at the honest 1:1 price (the patched TWAP clamp reads
/// `snapshot30min_old`, which only reports a populated snapshot after three
/// rotations). Trading is never opened — exactly like the official deploy —
/// and the fixture never touches any privileged entry point.
abstract contract LbpWorld {
    VmCheat internal constant VM = VmCheat(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address internal constant DEV_WALLET = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    bytes32 internal constant HR_SALT = 0x0000000000000000000000000000000000000000000000000000000000001001;
    uint256 internal constant SEED = 10_000 * 1e18;

    MockUSDT internal usdt;
    PancakeFactory internal pancake;
    HashrateRegistry internal registry;
    LBP internal lbp;
    PancakePair internal pair;
    HashrateStub internal hr;

    function _deployWorld() internal {
        // ---------- predicted addresses ----------
        address usdtPred = _createAddr(1);
        address factoryPred = _createAddr(2);
        address routerPred = _createAddr(3);
        address registryPred = _createAddr(4);
        address burnPred = _createAddr(5);
        address refPred = _createAddr(6);
        address polPred = _createAddr(7);
        address fomoPred = _createAddr(8);
        // HashrateStub via CREATE2 from this contract (burns nonce 9).
        address hrPred = _create2Addr(address(this), HR_SALT, type(HashrateStub).creationCode);

        // LBP needs the first nonce >= 10 whose predicted address orders above
        // USDT (constructor invariant: address(lbp) > address(usdt), i.e.
        // token0 == USDT). CREATE addresses are pseudorandom in the nonce, so
        // NoncePad contracts fill any gap. The bound is pure paranoia: the
        // search terminates after ~2 iterations in expectation.
        uint256 lbpNonce = 10;
        while (uint160(_createAddr(lbpNonce)) <= uint160(usdtPred)) {
            lbpNonce++;
            require(lbpNonce < 200, "world: no LBP address found");
        }
        address lbpPred = _createAddr(lbpNonce);

        // The pair is deployed by PancakeFactory.createPair inside LBP's
        // constructor: CREATE2 with salt keccak256(token0 || token1) over
        // PancakePair's creation code. usdt < lbp by construction, so the
        // sorted pair is (usdt, lbp).
        bytes32 pairSalt = keccak256(abi.encodePacked(usdtPred, lbpPred));
        address pairPred = _create2Addr(factoryPred, pairSalt, type(PancakePair).creationCode);

        // ---------- deploy in nonce order ----------
        usdt = new MockUSDT("Tether USD", "USDT");
        require(address(usdt) == usdtPred, "world: USDT off prediction");

        pancake = new PancakeFactory();
        require(address(pancake) == factoryPred, "world: factory off prediction");

        RouterStub router = new RouterStub();
        require(address(router) == routerPred, "world: router off prediction");

        registry =
            new HashrateRegistry(lbpPred, hrPred, pairPred, burnPred, refPred, polPred, fomoPred);
        require(address(registry) == registryPred, "world: registry off prediction");

        BurnVaultStub burn = new BurnVaultStub();
        require(address(burn) == burnPred, "world: burn vault off prediction");
        RefVaultStub ref = new RefVaultStub();
        require(address(ref) == refPred, "world: ref vault off prediction");
        PolVaultStub pol = new PolVaultStub();
        require(address(pol) == polPred, "world: pol vault off prediction");
        FomoVaultStub fomo = new FomoVaultStub();
        require(address(fomo) == fomoPred, "world: fomo vault off prediction");

        hr = new HashrateStub{salt: HR_SALT}();
        require(address(hr) == hrPred, "world: hashrate off prediction");

        for (uint256 n = 10; n < lbpNonce; n++) {
            NoncePad pad = new NoncePad();
            require(address(pad) == _createAddr(n), "world: nonce pad off prediction");
        }

        lbp = new LBP(
            keccak256("littleboy"),
            DEV_WALLET,
            address(this),
            IERC20(address(usdt)),
            IPancakeFactory(address(pancake)),
            registry,
            address(router)
        );
        require(address(lbp) == lbpPred, "world: LBP off prediction");
        require(lbp.pair() == pairPred, "world: pair off prediction");
        pair = PancakePair(pairPred);

        // ---------- seed: this contract provides the initial liquidity ----------
        usdt.mint(address(this), SEED);
        usdt.transfer(address(pair), SEED);
        lbp.transfer(address(pair), SEED);
        pair.mint(address(this));
        // Flush the bootstrap stage so the seed LP's honest hashrate
        // materialises (Layer 7a settle on a zero-value self transfer).
        lbp.transfer(address(this), address(this), 0);

        // ---------- 30-minute TWAP cascade at the honest 1:1 price ----------
        // Three rotations 10 minutes apart fill the old/mid/new ladder, so
        // snapshot30min_old carries a real sample. Identical on both trees;
        // the patched settle's TWAP clamp is inert without it.
        for (uint256 i = 0; i < 3; i++) {
            VM.warp(block.timestamp + 600);
            lbp.transfer(address(this), address(this), 0);
        }
    }

    /// @dev keccak(rlp(sender, nonce)) for single-byte nonce RLP (nonce 1..127).
    function _createAddr(uint256 nonce) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"d6", hex"94", bytes20(address(this)), uint8(nonce))
                    )
                )
            )
        );
    }

    /// @dev keccak(0xff ++ deployer ++ salt ++ keccak(initCode)) -- the
    ///      CREATE2 address formula.
    function _create2Addr(address deployer, bytes32 salt, bytes memory initCode)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", deployer, salt, keccak256(initCode)))))
        );
    }
}

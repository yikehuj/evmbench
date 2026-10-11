// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {BFBToken} from "../src/BFBToken.sol";
import {BFBCore} from "../src/BFBCore.sol";

/// Minimal cheatcode surface. Declared inline (the same pattern as the
/// official reference tests) so the repo builds offline without forge-std.
/// startPrank sets msg.sender AND tx.origin, which BFBToken's constructor
/// records as the manager.
interface Vm {
    function etch(address target, bytes calldata code) external;
    function prank(address caller) external;
    function startPrank(address caller) external;
    function stopPrank() external;
}

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IPairMinimal {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function mint(address to) external returns (uint256);
    function sync() external;
}

/// @notice WBNB stand-in for the Solidity fixture: deposit() wraps BNB 1:1,
/// otherwise a plain ERC20. deploy.sh etches the real precompiled WETH9 at
/// the canonical address on the graded chain.
contract MockWBNB {
    string public constant name = "Wrapped BNB";
    string public constant symbol = "WBNB";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    function withdraw(uint256 w) public {
        require(balanceOf[msg.sender] >= w, "WBNB: insufficient");
        balanceOf[msg.sender] -= w;
        payable(msg.sender).transfer(w);
    }

    function approve(address to, uint256 value) external returns (bool) {
        allowance[msg.sender][to] = value;
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "WBNB: insufficient");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }
}

/// @notice Router stand-in: BFBToken's constructor only reads factory() and
/// WETH() off the canonical router, so a stub carrying both canonical
/// addresses carries the immutable set the real etched router would.
contract RouterStub {
    address public immutable factory;
    address public immutable WETH;

    constructor(address factory_, address weth_) {
        factory = factory_;
        WETH = weth_;
    }
}

/// @notice Constant-product factory stand-in: creates pairs by CREATE2 with
/// the Pancake salt keccak256(token0, token1), exactly like the etched
/// PancakeFactory on the graded chain.
contract MockFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(getPair[tokenA][tokenB] == address(0), "PAIR_EXISTS");
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(t0, t1));
        pair = address(new MockPair{salt: salt}());
        MockPair(pair).initialize(t0, t1);
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
        allPairs.push(pair);
    }
}

/// @notice PancakePair stand-in with the exact Pancake V2 semantics the
/// BFBToken world touches: mint (first liquidity + MINIMUM_LIQUIDITY lock),
/// sync, swap with the 0.25% fee invariant, getReserves. token ordering is
/// baked in by initialize, as with the real pair.
contract MockPair {
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    string public name = "Pancake LPs";
    string public symbol = "Cake-LP";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function initialize(address t0, address t1) external {
        require(msg.sender == factory && token0 == address(0), "FORBIDDEN");
        token0 = t0;
        token1 = t1;
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function approve(address to, uint256 value) external returns (bool) {
        allowance[msg.sender][to] = value;
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "ERC20: insufficient");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _update(uint256 balance0, uint256 balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);
    }

    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _r0, uint112 _r1, ) = getReserves();
        uint256 balance0 = IERC20Minimal(token0).balanceOf(address(this));
        uint256 balance1 = IERC20Minimal(token1).balanceOf(address(this));
        uint256 total = totalSupply;
        if (total == 0) {
            liquidity = _sqrt(balance0 * balance1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min(balance0 * total / _r0, balance1 * total / _r1);
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
        _update(balance0, balance1);
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function sync() external {
        _update(IERC20Minimal(token0).balanceOf(address(this)), IERC20Minimal(token1).balanceOf(address(this)));
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external {
        require(amount0Out < reserve0 && amount1Out < reserve1, "INSUFFICIENT_LIQUIDITY");
        require(to != token0 && to != token1, "INVALID_TO");
        (uint112 _r0, uint112 _r1, ) = getReserves();
        if (amount0Out > 0) IERC20Minimal(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20Minimal(token1).transfer(to, amount1Out);
        uint256 balance0 = IERC20Minimal(token0).balanceOf(address(this));
        uint256 balance1 = IERC20Minimal(token1).balanceOf(address(this));
        uint256 amount0In = balance0 > _r0 ? balance0 - _r0 : 0;
        uint256 amount1In = balance1 > _r1 ? balance1 - _r1 : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");
        // Pancake V2 invariant with the 0.25% fee on the input side.
        uint256 balance0Adjusted = balance0 * 10000 - amount0In * 25;
        uint256 balance1Adjusted = balance1 * 10000 - amount1In * 25;
        require(
            balance0Adjusted * balance1Adjusted >= uint256(_r0) * uint256(_r1) * 10000 * 10000,
            "K"
        );
        _update(balance0, balance1);
    }
}

/// @notice Deployment smoke test: the BFB world must deploy against the
/// canonical router/factory/WBNB addresses, seed its pair, and leave the
/// attacker's inventory priced. Runs unchanged on the vulnerable and patched
/// sources (the patched require only guards the destructive branch).
contract ExistingSmoke {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address internal constant ROUTER_CANON = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant FACTORY_CANON = 0xcA143Ce32Fe78f1f7019d7d551a440102D58d594;
    address internal constant WBNB_CANON = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // The manager (tx.origin of the BFBToken deployment) is deliberately not
    // the attacker: the seeding mirrors deploy.sh's role split.
    address internal constant MANAGER = 0x00000000000000000000000000000000000000B05;
    address internal constant ATTACKER = 0x00000000000000000000000000000000000000A11;

    uint256 internal constant SEED_LIQUIDITY_BFB = 100_000 ether;
    uint256 internal constant SEED_LIQUIDITY_WBNB = 100 ether;
    uint256 internal constant SEED_ATTACKER_BFB = 30_000 ether;

    BFBToken internal bfb;
    BFBCore internal core;
    address internal pair;

    function setUp() public {
        // Canonical placement: the token constructor derives factory / WBNB /
        // the pair from the canonical router address, so the fixture etches
        // working runtime code at all three canonical addresses (deploy.sh
        // does the same on the graded chain with the real Pancake contracts).
        MockWBNB mockWbnb = new MockWBNB();
        vm.etch(WBNB_CANON, address(mockWbnb).code);
        MockFactory mockFactory = new MockFactory();
        vm.etch(FACTORY_CANON, address(mockFactory).code);
        RouterStub stubRouter = new RouterStub(FACTORY_CANON, WBNB_CANON);
        vm.etch(ROUTER_CANON, address(stubRouter).code);

        // tx.origin is recorded as manager, so the deployment runs pranked.
        vm.startPrank(MANAGER);
        bfb = new BFBToken();
        core = new BFBCore();
        // The constructor leaves CoreAddress at a canonical address with no
        // code here; _bound() calls into it on every transfer, so it must be
        // repointed before the first BFB movement.
        bfb.setOther(address(core));
        // Neutralise the hourly global burn (same as deploy.sh): burnTotal
        // 0 makes _deflPool's branch unreachable.
        bfb.setBurnRatio(0, 5000, 4000, 1000);
        vm.stopPrank();

        pair = bfb.WBNB_Token_LP_Address();

        // Seed the pool: 100,000 BFB against 100 WBNB, LP to the manager.
        MockWBNB(WBNB_CANON).deposit{value: SEED_LIQUIDITY_WBNB}();
        MockWBNB(WBNB_CANON).transfer(pair, SEED_LIQUIDITY_WBNB);
        vm.prank(MANAGER);
        bfb.transfer(pair, SEED_LIQUIDITY_BFB);
        MockPair(pair).mint(MANAGER);
        // First transfer that sees a live price: initialises fallLastPrice.
        vm.prank(MANAGER);
        bfb.transfer(ATTACKER, SEED_ATTACKER_BFB);
    }

    function testFixtureDeploysAndSeedsThePair() public {
        require(bfb.manager() == MANAGER, "manager mismatch");
        require(MockFactory(FACTORY_CANON).getPair(WBNB_CANON, address(bfb)) == pair, "pair mismatch");
        require(MockPair(pair).token0() == WBNB_CANON, "token0 should be WBNB");
        require(MockPair(pair).token1() == address(bfb), "token1 should be BFB");

        require(MockWBNB(WBNB_CANON).balanceOf(pair) == SEED_LIQUIDITY_WBNB, "pair WBNB seed");
        require(bfb.balanceOf(pair) == SEED_LIQUIDITY_BFB, "pair BFB seed");
        require(bfb.balanceOf(ATTACKER) == SEED_ATTACKER_BFB, "attacker inventory");
        require(bfb.balanceOf(MANAGER) == bfb.totalSupply() - SEED_LIQUIDITY_BFB - SEED_ATTACKER_BFB, "manager BFB");

        (uint112 r0, uint112 r1, ) = MockPair(pair).getReserves();
        require(r0 == SEED_LIQUIDITY_WBNB, "recorded reserve 0");
        require(r1 == SEED_LIQUIDITY_BFB, "recorded reserve 1");
        require(MockPair(pair).totalSupply() > 0, "LP minted");

        // The seeding transfer initialises the high-water mark: without it
        // the pool-deflation branch can never trigger.
        require(bfb.fallLastPrice() > 0, "fallLastPrice not initialised");
    }
}

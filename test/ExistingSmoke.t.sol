// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {SupperLuckyToken} from "../src/supperLucky/SupperLuckyToken.sol";
import {MockFactory, MockPair, MockRouter} from "../src/mocks/MockPair.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// Minimal cheatcode surface. Declared inline (the same pattern as the
/// official reference tests) so the repo builds offline without forge-std.
interface Vm {
    function etch(address target, bytes calldata code) external;
    function prank(address caller) external;
    function startPrank(address caller) external;
    function stopPrank() external;
}

address constant ROUTER_CANON = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant USDT_CANON = 0x55d398326f99059fF775485246999027B3197955;

/// @notice Deployment smoke test: the SupperLuckyToken fixture must deploy,
/// bind to its BSC-canonical router/USDT addresses, and seed the pair through
/// the whitelisted path. Runs unchanged on the vulnerable and patched sources.
contract ExistingSmoke {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    SupperLuckyToken internal token;
    MockPair internal pair;

    address internal holder = 0x00000000000000000000000000000000000000A11;

    function setUp() public {
        // The token constructor hardcodes the BSC router/USDT addresses on
        // every chain except 97, so the fixture transplants the mock router
        // and USDT runtime code to those canonical addresses. Etching runtime
        // bytecode keeps constructor-baked immutables (router.factory(),
        // usdt.decimals) intact.
        MockFactory factory = new MockFactory();
        MockRouter router = new MockRouter(address(factory));
        MockERC20 usdt = new MockERC20("Tether", "USDT", 18);
        vm.etch(ROUTER_CANON, address(router).code);
        vm.etch(USDT_CANON, address(usdt).code);

        vm.prank(holder);
        token = new SupperLuckyToken("Supper Lucky", "SKP", holder);
        pair = MockPair(token.usdtPair());

        // Seed the pool the way deploy.sh does: 1,000,000 USDT against
        // 401,000 SKP, moved while the holder is fee-whitelisted.
        MockERC20(USDT_CANON).mint(address(pair), 1_000_000 ether);
        vm.startPrank(holder);
        token.transfer(address(pair), 401_000 ether);
        token.setContractAddress(holder, holder);
        token.setFeeWhiteList(holder, false);
        vm.stopPrank();
    }

    function _expectEq(uint256 a, uint256 b, string memory what) internal pure {
        require(a == b, what);
    }

    function testFixtureDeploysAndSeedsThePair() public {
        _expectEq(token.usdtPair() == address(pair) ? 1 : 0, 1, "pair mismatch");
        _expectEq(MockERC20(USDT_CANON).balanceOf(address(pair)), 1_000_000 ether, "pair USDT seed");
        _expectEq(token.balanceOf(address(pair)), 401_000 ether, "pair SKP seed");
        _expectEq(token.balanceOf(holder), 10_000_000_000 ether - 401_000 ether, "holder SKP");
        _expectEq(token.totalSupply(), 10_000_000_000 ether, "SKP total supply");
        _expectEq(token.owner() == holder ? 1 : 0, 1, "owner");

        // Recorded reserves keep their constructor values because the
        // whitelisted seeding path never syncs the pair.
        (uint112 r0, uint112 r1,) = pair.getReserves();
        _expectEq(uint256(r0), 1e24, "recorded reserve 0");
        _expectEq(uint256(r1), 1e24, "recorded reserve 1");
    }

    function testWhitelistedTransferMovesTheFullAmount() public {
        vm.prank(holder);
        token.setFeeWhiteList(holder, true);
        vm.prank(holder);
        token.transfer(address(pair), 1_000 ether);
        _expectEq(token.balanceOf(address(pair)), 402_000 ether, "pair SKP after transfer");
        _expectEq(token.totalSupply(), 10_000_000_000 ether, "supply unchanged");
    }
}

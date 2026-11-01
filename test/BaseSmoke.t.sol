pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";

import {Timelock} from "src/Timelock.sol";
import {MockSafe} from "test/mock/MockSafe.sol";
import {MIN_DELAY} from "src/utils/Constants.sol";

/// @notice Constructor-agnostic smoke test. It only exercises the stable
/// surface that exists both before and after the audit fixes: deployment,
/// basic getters, and scheduling a single timelocked operation.
contract BaseSmokeTest is Test {
    Timelock internal timelock;
    MockSafe internal safe;

    address internal constant HOT_SIGNER = address(0xA11CE);
    address internal constant GUARDIAN = address(0x11111);
    uint256 internal constant EXPIRATION_PERIOD = 5 days;
    uint128 internal constant PAUSE_DURATION = 10 days;

    function setUp() public {
        /// move past the initial pause window so schedule() is callable
        vm.warp(1_000_000 + uint256(PAUSE_DURATION));

        safe = new MockSafe();

        address[] memory hotSigners = new address[](1);
        hotSigners[0] = HOT_SIGNER;

        timelock = new Timelock(
            address(safe),
            MIN_DELAY,
            EXPIRATION_PERIOD,
            GUARDIAN,
            PAUSE_DURATION,
            hotSigners
        );
    }

    function testBaseSmoke() public {
        assertEq(timelock.safe(), address(safe), "safe");
        assertEq(timelock.minDelay(), MIN_DELAY, "minDelay");
        assertEq(timelock.pauseGuardian(), GUARDIAN, "guardian");
        assertFalse(timelock.paused(), "should not be paused");
        assertEq(timelock.getAllProposals().length, 0, "no proposals");

        bytes memory data =
            abi.encodeWithSelector(timelock.updateDelay.selector, MIN_DELAY);
        bytes32 salt = bytes32("base-smoke");

        vm.prank(address(safe));
        timelock.schedule(address(timelock), 0, data, salt, MIN_DELAY);

        bytes32 id =
            timelock.hashOperation(address(timelock), 0, data, salt);
        assertTrue(timelock.isOperation(id), "operation not live");
        assertEq(timelock.getAllProposals().length, 1, "proposal not tracked");
    }
}

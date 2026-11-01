// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {RocketJoeToken} from "../../contracts/RocketJoeToken.sol";
import {RocketJoeStaking} from "../../contracts/RocketJoeStaking.sol";

/// @dev Minimal WAVAX stand-in: `deposit()` mints wrapped balance to itself.
contract MockWAVAX is ERC20("Wrapped AVAX", "WAVAX") {
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}

/// @dev Minimal JoePair stand-in: `mint` mints LP shares to the caller-specified holder.
contract MockJoePair is ERC20("Joe LP", "JOE-LP") {
    uint256 public constant MINT_AMOUNT = 10 ether;

    function mint(address to) external returns (uint256 amount) {
        amount = MINT_AMOUNT;
        _mint(to, amount);
    }
}

/// @dev Factory/registry stand-in for LaunchEvent. Implements the getters
/// LaunchEvent.initialize() reads, plus getPair/createPair used by createPair().
contract MockLaunchFactory {
    address public wavax;
    address public router;
    address public factory;
    address public rJoe;
    uint256 public rJoePerAvax;
    uint256 public PHASE_ONE_DURATION;
    uint256 public PHASE_ONE_NO_FEE_DURATION;
    uint256 public PHASE_TWO_DURATION;
    address public penaltyCollector;
    address public owner;
    address public pairAddress;

    constructor(
        address _wavax,
        address _router,
        address _factory,
        address _rJoe,
        uint256 _rJoePerAvax,
        uint256 _phaseOneDuration,
        uint256 _phaseOneNoFeeDuration,
        uint256 _phaseTwoDuration,
        address _penaltyCollector
    ) {
        wavax = _wavax;
        router = _router;
        factory = _factory;
        rJoe = _rJoe;
        rJoePerAvax = _rJoePerAvax;
        PHASE_ONE_DURATION = _phaseOneDuration;
        PHASE_ONE_NO_FEE_DURATION = _phaseOneNoFeeDuration;
        PHASE_TWO_DURATION = _phaseTwoDuration;
        penaltyCollector = _penaltyCollector;
        owner = msg.sender;
    }

    function setFactory(address value) external {
        factory = value;
    }

    function getPair(address, address) external view returns (address) {
        return pairAddress;
    }

    function createPair(address, address) external returns (address) {
        if (pairAddress == address(0)) {
            pairAddress = address(new MockJoePair());
        }
        return pairAddress;
    }
}

/// @dev LaunchEvent participant that re-enters skim() from its AVAX receive hook.
contract ReentrantWithdrawer {
    address public launchEvent;
    bool public armed;

    constructor(address _launchEvent) {
        launchEvent = _launchEvent;
    }

    function setArmed(bool value) external {
        armed = value;
    }

    function deposit() external payable {
        (bool ok, ) = launchEvent.call{value: msg.value}(
            abi.encodeWithSignature("depositAVAX()")
        );
        require(ok, "deposit failed");
    }

    function withdraw(uint256 amount) external {
        (bool ok, ) = launchEvent.call(
            abi.encodeWithSignature("withdrawAVAX(uint256)", amount)
        );
        require(ok, "withdraw failed");
    }

    receive() external payable {
        if (armed) {
            armed = false;
            (bool ok, ) = launchEvent.call(abi.encodeWithSignature("skim()"));
            require(ok, "skim failed");
        }
    }
}

interface IRJoeCallback {
    function onRJoeReceived() external;
}

/// @dev rJOE token that calls back into a configured address on every transfer.
/// RocketJoeToken inherits OZ ERC20, whose `transfer` is virtual.
contract ReentrantRJoe is RocketJoeToken {
    address public callbackTarget;
    bool public armed;

    function configure(address target, bool value) external {
        callbackTarget = target;
        armed = value;
    }

    function setArmed(bool value) external {
        armed = value;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        bool ok = super.transfer(to, amount);
        if (armed && to == callbackTarget && amount > 0) {
            IRJoeCallback(callbackTarget).onRJoeReceived();
        }
        return ok;
    }
}

/// @dev Staker that re-enters deposit(0) whenever it receives rJOE.
contract RJoeAttacker {
    ERC20 public joe;
    RocketJoeStaking public staking;
    uint256 public depth;
    uint256 public maxDepth;
    bool public reenter;

    constructor(address _joe, address _staking) {
        joe = ERC20(_joe);
        staking = RocketJoeStaking(_staking);
    }

    function configure(bool value, uint256 _maxDepth) external {
        reenter = value;
        maxDepth = _maxDepth;
    }

    function deposit(uint256 amount) external {
        joe.approve(address(staking), amount);
        staking.deposit(amount);
    }

    function onRJoeReceived() external {
        if (reenter && depth < maxDepth) {
            depth += 1;
            staking.deposit(0);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PancakePair} from "./PancakePair.sol";

/// @notice Minimal PancakeSwap V2 factory. `createPair` uses CREATE2 with a
///         deterministic salt (keccak256(sorted token pair)) so the LBP/USDT pair
///         address can be predicted off-chain and baked into HashrateRegistry.
contract PancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor() {
        feeToSetter = msg.sender;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "Pancake: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "Pancake: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Pancake: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Pancake: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Pancake: PAIR_EXISTS");
        bytes memory bytecode = type(PancakePair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        PancakePair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}

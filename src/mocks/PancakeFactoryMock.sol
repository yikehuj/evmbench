// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PancakePairMock.sol";

// Minimal Pancake factory: `createPair(tokenA, tokenB)` deploys a pair and
// keeps `token0 = tokenA`, `token1 = tokenB` (argument order, no address sort)
// so the DIP constructor's `createPair(DIP, AIC)` deterministically yields a
// pair with token0 = DIP, token1 = AIC.
contract PancakeFactoryMock {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Pancake: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "Pancake: ZERO_ADDRESS");
        require(getPair[tokenA][tokenB] == address(0), "Pancake: PAIR_EXISTS");
        PancakePairMock p = new PancakePairMock(address(this));
        p.initialize(tokenA, tokenB);
        getPair[tokenA][tokenB] = address(p);
        allPairs.push(address(p));
        pair = address(p);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import {LegendaryMoneyMonNft} from "./LegendaryMoneyMonNft.sol";
import {SeededMON} from "./SeededMON.sol";
contract Scenario {
 address public constant VICTIM=0xaCc0c1f672B03B9a5fED4535f840f09B85f40E98;
 LegendaryMoneyMonNft public immutable nft; SeededMON public immutable mon;
 constructor(){ nft=new LegendaryMoneyMonNft(msg.sender); mon=new SeededMON(address(nft),100_000 ether); }
}

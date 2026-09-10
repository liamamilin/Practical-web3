// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Crowdfund} from "../src/Crowdfund.sol";

contract Deploy is Script {
    function run() external returns (Crowdfund crowdfund) {
        // 目标 10 ether、募集 7 天、最低出资 0.01 ether
        uint256 goal = 10 ether;
        uint64 durationDays = 7;
        uint256 minContribution = 0.01 ether;

        vm.startBroadcast();
        crowdfund = new Crowdfund(goal, durationDays, minContribution);
        vm.stopBroadcast();

        console.log("Crowdfund deployed at:", address(crowdfund));
        console.log("goal (wei):", goal);
        console.log("deadline (unix):", crowdfund.deadline());
    }
}

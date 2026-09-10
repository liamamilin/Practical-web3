// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice 第 3 章实验用的极简计数器合约：演示合约交互交易的 Data 字段。
contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}

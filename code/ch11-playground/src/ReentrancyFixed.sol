// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title 重入漏洞靶场：修复版
/// @notice 与漏洞版唯一的区别是 withdraw 里三步的顺序：
///         checks（检查）→ effects（改状态）→ interactions（外部调用）。
///         改动小到荒谬，但同一攻击者打不动它——顺序就是安全。
import {IBank} from "./IBank.sol";

contract ReentrancyFixed is IBank {
    mapping(address => uint256) public balances;

    error InsufficientBalance(uint256 requested, uint256 available);
    error DepositMustBePositive();
    error TransferFailed();

    // 纵深防御：重入互斥锁。CEI 已经足以挡住本靶场的攻击，
    // 但跨函数重入等变种依然存在，生产合约通常两者都加。
    uint256 private unlocked = 1;

    modifier nonReentrant() {
        if (unlocked != 1) revert TransferFailed();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() payable {}

    function deposit() external payable {
        if (msg.value == 0) revert DepositMustBePositive();
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external nonReentrant {
        // 1. checks
        uint256 balance = balances[msg.sender];
        if (amount > balance) revert InsufficientBalance(amount, balance);

        // 2. effects：先改状态。重入者看到的余额已经是扣过的
        balances[msg.sender] = balance - amount;

        // 3. interactions：最后才把控制流交出去
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title 重入漏洞靶场：漏洞版
/// @notice 看起来完全正常的"存取款银行"。漏洞只有一处：withdraw 里
///         "先给钱、后改账本"——checks 做了，effects 放到了 interactions 之后。
/// @dev 攻击过程见 test/Reentrancy.t.sol 与本书第 11 章。
import {IBank} from "./IBank.sol";

contract ReentrancyVulnerable is IBank {
    mapping(address => uint256) public balances;

    error InsufficientBalance(uint256 requested, uint256 available);
    error DepositMustBePositive();
    error TransferFailed();

    constructor() payable {}

    function deposit() external payable {
        if (msg.value == 0) revert DepositMustBePositive();
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        // checks：余额够吗？——这一步是对的
        uint256 balance = balances[msg.sender];
        if (amount > balance) revert InsufficientBalance(amount, balance);

        // interactions：先给钱。低级 call 把控制流交给了对方合约！
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        // effects：后改账本。——如果对方在收到钱的那一刻又调了 withdraw，
        // 它看到的还是"没扣过"的旧余额。这就是重入。
        balances[msg.sender] = balance - amount;
    }
}

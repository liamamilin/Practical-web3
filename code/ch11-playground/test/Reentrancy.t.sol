// SPDX-License-Identifier: MIT
// 已在 Foundry 1.8.1 / Solc 0.8.30 下实机验证通过（4/4 PASS）。
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IBank} from "../src/IBank.sol";
import {ReentrancyAttacker} from "../src/ReentrancyAttacker.sol";
import {ReentrancyFixed} from "../src/ReentrancyFixed.sol";
import {ReentrancyVulnerable} from "../src/ReentrancyVulnerable.sol";

contract ReentrancyPlaygroundTest is Test {
    ReentrancyVulnerable vulnerableBank;
    ReentrancyFixed fixedBank;

    address user;

    uint256 constant BANK_DEPOSIT = 10 ether;
    uint256 constant ATTACK_STAKE = 1 ether;

    function setUp() public {
        vulnerableBank = new ReentrancyVulnerable();
        fixedBank = new ReentrancyFixed();
        // 两个银行各躺 10 ETH"其他用户的存款"
        deal(address(vulnerableBank), BANK_DEPOSIT);
        deal(address(fixedBank), BANK_DEPOSIT);
        user = makeAddr("user");
    }

    // ==================== 漏洞版：得手 ====================

    function test_VulnerableBankGetsDrained() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(vulnerableBank);

        attacker.attack{value: ATTACK_STAKE}();

        // 银行被清空：10 ETH 存款 + 攻击者自己的 1 ETH 全部流出
        assertEq(address(vulnerableBank).balance, 0);
        // 重入共发生 11 次（攻击者本金 1 + 其他用户 10）
        assertEq(attacker.stolen(), BANK_DEPOSIT + ATTACK_STAKE);
        assertEq(address(attacker).balance, BANK_DEPOSIT + ATTACK_STAKE);
        // 受害者视角：账本上 attacker 的余额还"合法"地写着 0 之后的状态
        assertEq(vulnerableBank.balances(address(attacker)), 0);
    }

    // ==================== 修复版：同一攻击者，同一战术，失败 ====================

    function test_FixedBankSurvivesSameAttack() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(fixedBank);

        attacker.attack{value: ATTACK_STAKE}();

        // 银行 10 ETH 分毫未损
        assertEq(address(fixedBank).balance, BANK_DEPOSIT);
        // 攻击者只拿回了自己的 1 ETH，一无所获
        assertEq(attacker.stolen(), 0);
        assertEq(address(attacker).balance, ATTACK_STAKE);
        assertEq(fixedBank.balances(address(attacker)), 0);
    }

    // ==================== 修复版：正常用户不受影响 ====================

    function test_FixedBankNormalUserCanDepositAndWithdraw() public {
        deal(user, 2 ether);

        vm.prank(user);
        fixedBank.deposit{value: 2 ether}();
        assertEq(fixedBank.balances(user), 2 ether);

        vm.prank(user);
        fixedBank.withdraw(1 ether);
        assertEq(fixedBank.balances(user), 1 ether);
        assertEq(user.balance, 1 ether);

        // 超额提款照常被拒绝
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ReentrancyFixed.InsufficientBalance.selector, 2 ether, 1 ether
            )
        );
        fixedBank.withdraw(2 ether);
    }

    // ==================== 漏洞版：正常路径也不报错（漏洞的隐蔽性所在）====================

    function test_VulnerableBankNormalPathWorksFine() public {
        deal(user, 2 ether);

        vm.prank(user);
        vulnerableBank.deposit{value: 2 ether}();

        vm.prank(user);
        vulnerableBank.withdraw(1 ether);
        assertEq(vulnerableBank.balances(user), 1 ether);
        assertEq(user.balance, 1 ether);
    }
}

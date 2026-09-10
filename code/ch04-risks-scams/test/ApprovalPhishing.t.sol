// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm, vm, console} from "../src/TestBare.sol";
import {MockToken} from "../src/MockToken.sol";
import {MaliciousSpender} from "../src/MaliciousSpender.sol";

/// @notice 第 4 章实验：在本地链上完整复现一次"钓鱼授权 → 搬币 → 撤销"。
///         全部使用测试代币与测试地址，零真实资金、零外部依赖。
contract ApprovalPhishingTest {
    MockToken token;
    MaliciousSpender scam;

    address victim; // 用户
    address attacker; // 骗局经营者
    uint256 constant MINT = 1000e18;

    function setUp() public {
        victim = vm.addr(1);
        attacker = vm.addr(2);
        vm.label(victim, "victim");
        vm.label(attacker, "attacker");

        token = new MockToken();
        scam = new MaliciousSpender(address(token), attacker);

        // 部署者（本测试合约）持有的初始代币，转给用户
        token.transfer(victim, MINT);
    }

    /// 第 1 步：用户（在伪造界面的诱导下）签署无限授权，随后被搬空。
    function test_01_ApproveIsAllItTakes() public {
        vm.prank(victim);
        // 用户以为自己在做别的事，实际签下的只是这一条：无限授权
        token.approve(address(scam), type(uint256).max);

        // 关键事实：授权之后，攻击者随时可以搬币，完全不需要用户在场
        vm.prank(attacker);
        scam.drain(victim);

        console.log("victim  balance after drain :", token.balanceOf(victim));
        console.log("attacker balance after drain:", token.balanceOf(attacker));
        require(token.balanceOf(victim) == 0, "victim should lose everything");
        require(token.balanceOf(attacker) == MINT, "attacker should get everything");
    }

    /// 第 2 步：撤销（revoke）= 再发一笔授权，额度改回 0，此后搬币必然失败。
    function test_02_RevokeStopsTheBleeding() public {
        // 用户只给了有限授权，攻击者搬走了被授权的部分（500 枚）
        vm.prank(victim);
        token.approve(address(scam), 500e18);
        vm.prank(attacker);
        scam.drain(victim);

        // 用户察觉，撤销授权
        vm.prank(victim);
        token.approve(address(scam), 0);

        // 攻击者想搬剩下的另一半：必须失败
        vm.prank(attacker);
        vm.expectRevert(bytes("insufficient allowance"));
        scam.tryDrainAfterRevoke(victim);

        console.log("victim balance after revoke:", token.balanceOf(victim));
        require(token.balanceOf(victim) == 500e18, "the other half should be safe");
        require(token.allowance(victim, address(scam)) == 0, "allowance should be cleared");
    }

    /// 第 3 步：展示授权的盲区——授权本身不移动任何代币，毫无体感，但通道全开。
    function test_03_ApproveAloneMovesNoMoney() public {
        uint256 victimBefore = token.balanceOf(victim);
        vm.prank(victim);
        token.approve(address(scam), type(uint256).max);

        require(token.balanceOf(victim) == victimBefore, "no tokens should move");
        require(
            token.allowance(victim, address(scam)) == type(uint256).max,
            "channel should be wide open"
        );
        console.log(unicode"approve 之后：余额未变，但授权额度已是 uint256 最大值");
    }
}

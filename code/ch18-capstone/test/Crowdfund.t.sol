// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Crowdfund} from "../src/Crowdfund.sol";

contract CrowdfundTest is Test {
    Crowdfund public crowdfund;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address recipient = makeAddr("recipient");

    uint256 constant GOAL = 10 ether;
    uint64 constant DURATION_DAYS = 7;
    uint256 constant MIN_CONTRIBUTION = 0.01 ether;

    function setUp() public {
        crowdfund = new Crowdfund(GOAL, DURATION_DAYS, MIN_CONTRIBUTION);
    }

    // ---------- 辅助函数 ----------

    function _votingEndsAt(uint256 proposalId) internal view returns (uint64) {
        (, , , uint64 votingEndsAt, , , , ) = crowdfund.proposals(proposalId);
        return votingEndsAt;
    }

    function _fund() internal {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}();
        vm.prank(bob);
        crowdfund.contribute{value: 4 ether}();
    }

    function _createVotedProposal() internal returns (uint256 proposalId) {
        vm.prank(alice);
        proposalId = crowdfund.createProposal("pay dev team", recipient, 2 ether);
        vm.prank(alice);
        crowdfund.vote(proposalId, true); // 权重 6
        vm.prank(bob);
        crowdfund.vote(proposalId, false); // 权重 4
    }

    function _passAndExecute(uint256 proposalId) internal {
        vm.warp(_votingEndsAt(proposalId) + 1);
        vm.prank(carol);
        crowdfund.execute(proposalId);
    }

    // ---------- 募集 ----------

    function test_Contribute_UpdatesState() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 0.5 ether}();
        assertEq(crowdfund.contributions(alice), 0.5 ether);
        assertEq(crowdfund.totalRaised(), 0.5 ether);
        assertEq(uint8(crowdfund.phase()), uint8(Crowdfund.Phase.Active));
    }

    function test_Contribute_SetsFundedPhaseAtGoal() public {
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        crowdfund.contribute{value: GOAL}();
        assertEq(uint8(crowdfund.phase()), uint8(Crowdfund.Phase.Funded));
    }

    function test_Contribute_RevertIfBelowMin() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(Crowdfund.ContributionTooSmall.selector);
        crowdfund.contribute{value: 0.001 ether}();
    }

    function test_Contribute_RevertIfAfterDeadline() public {
        vm.deal(alice, 1 ether);
        vm.warp(crowdfund.deadline());
        vm.prank(alice);
        vm.expectRevert(Crowdfund.NotActive.selector);
        crowdfund.contribute{value: 0.1 ether}();
    }

    function testFuzz_Contribute_TotalTracksSum(uint96 a, uint96 b) public {
        a = uint96(bound(a, MIN_CONTRIBUTION, 5 ether));
        b = uint96(bound(b, MIN_CONTRIBUTION, 5 ether));
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.prank(alice);
        crowdfund.contribute{value: a}();
        vm.prank(bob);
        crowdfund.contribute{value: b}();
        assertEq(crowdfund.totalRaised(), uint256(a) + uint256(b));
        assertEq(crowdfund.treasury(), uint256(a) + uint256(b));
    }

    // ---------- 退款 ----------

    function test_Refund_ReturnsFunds() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 0.5 ether}();
        uint256 before = alice.balance;
        vm.warp(crowdfund.deadline() + 1);
        vm.prank(alice);
        crowdfund.refund();
        assertEq(alice.balance, before + 0.5 ether);
        assertEq(crowdfund.contributions(alice), 0);
        assertEq(uint8(crowdfund.phase()), uint8(Crowdfund.Phase.Refunding));
    }

    function test_Refund_AllowsMultipleContributors() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 0.5 ether}();
        vm.prank(bob);
        crowdfund.contribute{value: 0.5 ether}();
        vm.warp(crowdfund.deadline() + 1);
        vm.prank(alice);
        crowdfund.refund(); // 首次退款：切到 Refunding
        vm.prank(bob);
        crowdfund.refund(); // 第二人仍可退款
        assertEq(crowdfund.treasury(), 0);
    }

    function test_Refund_RevertIfGoalReached() public {
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        crowdfund.contribute{value: GOAL}();
        vm.warp(crowdfund.deadline() + 1);
        vm.prank(alice);
        vm.expectRevert(Crowdfund.NotRefunding.selector);
        crowdfund.refund();
    }

    function test_Refund_RevertIfBeforeDeadline() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 0.5 ether}();
        vm.prank(alice);
        vm.expectRevert(Crowdfund.NotRefunding.selector);
        crowdfund.refund();
    }

    // ---------- 提案 ----------

    function test_CreateProposal_StoresFields() public {
        _fund();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("pay dev team", recipient, 2 ether);
        (string memory description, address to, uint256 amount, uint64 endsAt, , , , ) =
            crowdfund.proposals(proposalId);
        assertEq(description, "pay dev team");
        assertEq(to, recipient);
        assertEq(amount, 2 ether);
        assertEq(endsAt, block.timestamp + 3 days);
    }

    function test_CreateProposal_RevertIfNotFunded() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 0.5 ether}();
        vm.prank(alice);
        vm.expectRevert(Crowdfund.NotFunded.selector);
        crowdfund.createProposal("x", recipient, 0.1 ether);
    }

    function test_CreateProposal_RevertIfExceedsTreasury() public {
        _fund();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Crowdfund.InsufficientTreasury.selector, 11 ether, 10 ether)
        );
        crowdfund.createProposal("x", recipient, 11 ether);
    }

    function test_CreateProposal_RevertIfZeroRecipient() public {
        _fund();
        vm.prank(alice);
        vm.expectRevert(Crowdfund.InvalidRecipient.selector);
        crowdfund.createProposal("x", address(0), 1 ether);
    }

    function test_CreateProposal_RevertIfEmptyDescription() public {
        _fund();
        vm.prank(alice);
        vm.expectRevert(Crowdfund.InvalidDescription.selector);
        crowdfund.createProposal("", recipient, 1 ether);
    }

    // ---------- 投票 ----------

    function test_Vote_WeightedByContribution() public {
        _fund();
        uint256 proposalId = _createVotedProposal();
        (, , , , uint256 votesFor, uint256 votesAgainst, , ) = crowdfund.proposals(proposalId);
        assertEq(votesFor, 6 ether);
        assertEq(votesAgainst, 4 ether);
    }

    function test_Vote_RevertIfAlreadyVoted() public {
        _fund();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("x", recipient, 1 ether);
        vm.prank(alice);
        crowdfund.vote(proposalId, true);
        vm.prank(alice);
        vm.expectRevert(Crowdfund.AlreadyVoted.selector);
        crowdfund.vote(proposalId, true);
    }

    function test_Vote_RevertIfNoVotingPower() public {
        _fund();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("x", recipient, 1 ether);
        vm.prank(carol);
        vm.expectRevert(Crowdfund.NoVotingPower.selector);
        crowdfund.vote(proposalId, true);
    }

    function test_Vote_RevertIfVotingClosed() public {
        _fund();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("x", recipient, 1 ether);
        vm.warp(_votingEndsAt(proposalId) + 1);
        vm.prank(alice);
        vm.expectRevert(Crowdfund.VotingClosed.selector);
        crowdfund.vote(proposalId, true);
    }

    // ---------- 执行 ----------

    function test_Execute_SendsFundsAndMarksExecuted() public {
        _fund();
        uint256 proposalId = _createVotedProposal();
        uint256 before = recipient.balance;
        _passAndExecute(proposalId);
        assertEq(recipient.balance, before + 2 ether);
        assertEq(crowdfund.spent(), 2 ether);
        assertEq(crowdfund.availableForProposals(), 8 ether);
    }

    function test_Execute_RevertIfQuorumNotMet() public {
        // 募集期就构造"小权重投票者"：alice 出 9.5、bob 出 0.5，总募资 10（达标）
        // 法定人数 = 10 * 10% = 1 ether；bob 权重仅 0.5，不足以过线
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.prank(alice);
        crowdfund.contribute{value: 9.5 ether}();
        vm.prank(bob);
        crowdfund.contribute{value: 0.5 ether}();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("x", recipient, 1 ether);
        vm.prank(bob);
        crowdfund.vote(proposalId, true); // 权重仅 0.5 < 1
        vm.warp(_votingEndsAt(proposalId) + 1);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Crowdfund.QuorumNotMet.selector, 0.5 ether, 1 ether)
        );
        crowdfund.execute(proposalId);
    }

    function test_Execute_RevertIfRejected() public {
        _fund();
        // alice（6）赞成、bob（4）反对：赞成 > 反对但反对票权重大于零时仍需严格多于
        // 构造反对更多：bob 6、alice 4 的池子
        Crowdfund c2 = new Crowdfund(GOAL, DURATION_DAYS, MIN_CONTRIBUTION);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.prank(alice);
        c2.contribute{value: 4 ether}();
        vm.prank(bob);
        c2.contribute{value: 6 ether}();
        vm.prank(alice);
        uint256 proposalId = c2.createProposal("x", recipient, 1 ether);
        vm.prank(alice);
        c2.vote(proposalId, true); // 4
        vm.prank(bob);
        c2.vote(proposalId, false); // 6
        vm.warp(block.timestamp + 3 days + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Crowdfund.ProposalRejected.selector, 4 ether, 6 ether));
        c2.execute(proposalId);
    }

    function test_Execute_RevertIfStillVoting() public {
        _fund();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("x", recipient, 1 ether);
        vm.prank(alice);
        crowdfund.vote(proposalId, true);
        vm.prank(carol);
        vm.expectRevert(Crowdfund.VotingOpen.selector);
        crowdfund.execute(proposalId);
    }

    function test_Execute_RevertIfExecutedTwice() public {
        _fund();
        uint256 proposalId = _createVotedProposal();
        _passAndExecute(proposalId);
        vm.prank(carol);
        vm.expectRevert(Crowdfund.AlreadyExecuted.selector);
        crowdfund.execute(proposalId);
    }

    function test_Execute_Invariant_TreasuryConsistency() public {
        _fund();
        uint256 proposalId = _createVotedProposal();
        _passAndExecute(proposalId);
        // 任意时刻：treasury == totalRaised - spent（无其他资金入口）
        assertEq(crowdfund.treasury(), crowdfund.totalRaised() - crowdfund.spent());
    }

    // ---------- 取消 ----------

    function test_Cancel_BlocksExecution() public {
        _fund();
        vm.prank(alice);
        uint256 proposalId = crowdfund.createProposal("x", recipient, 1 ether);
        vm.prank(bob);
        crowdfund.cancel(proposalId);
        vm.warp(block.timestamp + 3 days + 1);
        vm.prank(carol);
        vm.expectRevert(Crowdfund.AlreadyExecuted.selector);
        crowdfund.execute(proposalId);
    }
}

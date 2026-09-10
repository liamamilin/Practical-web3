// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Crowdfund — 带链上治理的资金使用投票众筹
/// @notice 教学参考实现：目标达成后，资金如何使用由出资人按出资比例投票决定。
/// @dev 全书第 18 章参考实现，代码经过设计以展示教学要点，未经过审计，请勿直接用于生产。
contract Crowdfund {
    // ---------- 类型 ----------

    /// @notice 众筹阶段
    enum Phase {
        Active,     // 募集中
        Funded,     // 达标，进入治理
        Refunding   // 未达标，可退款
    }

    /// @notice 资金使用提案
    struct Proposal {
        string description;
        address recipient;
        uint256 amount;
        uint64 votingEndsAt;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool canceled;
    }

    // ---------- 状态 ----------

    address public immutable creator;
    uint256 public immutable goal;
    uint64 public immutable deadline;
    uint256 public minContribution;

    mapping(address => uint256) public contributions;
    address[] private _contributors;

    Phase public phase;
    uint256 public totalRaised;
    uint256 public spent;

    Proposal[] public proposals;

    // 投票记录：提案 id => 投票人 => 是否已投
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // 治理参数（教学用固定值，真实协议中这些应当可治理修改）
    uint64 public constant VOTING_PERIOD = 3 days;
    uint256 public constant QUORUM_NUMERATOR = 10; // 达标线：10% 出资权参与投票
    uint256 public constant QUORUM_DENOMINATOR = 100;

    // ---------- 事件 ----------

    event Contributed(address indexed contributor, uint256 amount, uint256 totalRaised);
    event Refunded(address indexed contributor, uint256 amount);
    event PhaseChanged(Phase indexed newPhase);
    event ProposalCreated(uint256 indexed proposalId, address recipient, uint256 amount, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address recipient, uint256 amount);
    event ProposalCanceled(uint256 indexed proposalId);

    // ---------- 错误 ----------

    error ContributionTooSmall();
    error NotActive();
    error NotRefunding();
    error NothingToRefund();
    error RefundFailed();
    error NotFunded();
    error VotingClosed();
    error VotingOpen();
    error NoVotingPower();
    error AlreadyVoted();
    error AlreadyExecuted();
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidDescription();
    error QuorumNotMet(uint256 votesFor, uint256 quorum);
    error ProposalRejected(uint256 votesFor, uint256 votesAgainst);
    error InsufficientTreasury(uint256 requested, uint256 available);

    // ---------- 修饰器 ----------

    modifier onlyFunded() {
        if (phase != Phase.Funded) revert NotFunded();
        _;
    }

    // ---------- 构造 ----------

    /// @param goal_ 目标金额（wei）
    /// @param durationDays_ 募集时长（天）
    /// @param minContribution_ 最低出资（wei）
    constructor(uint256 goal_, uint64 durationDays_, uint256 minContribution_) {
        require(goal_ > 0, "goal must be > 0");
        require(durationDays_ > 0, "duration must be > 0");
        creator = msg.sender;
        goal = goal_;
        deadline = uint64(block.timestamp + durationDays_ * 1 days);
        minContribution = minContribution_;
        phase = Phase.Active;
    }

    // ---------- 募集 ----------

    /// @notice 出资。达标时自动切换到 Funded 阶段。
    function contribute() external payable {
        if (phase != Phase.Active) revert NotActive();
        if (block.timestamp >= deadline) revert NotActive();
        if (msg.value < minContribution) revert ContributionTooSmall();

        if (contributions[msg.sender] == 0) {
            _contributors.push(msg.sender);
        }
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        if (totalRaised >= goal) {
            phase = Phase.Funded;
            emit PhaseChanged(Phase.Funded);
        }
        emit Contributed(msg.sender, msg.value, totalRaised);
    }

    /// @notice 未达标时取回全部出资（pull 模式）。首次调用会把阶段切换为 Refunding，
    ///         Refunding 阶段仍允许其余出资人逐一退款。
    function refund() external {
        if (phase == Phase.Funded) revert NotRefunding();
        if (block.timestamp < deadline) revert NotRefunding();
        if (phase == Phase.Active) {
            phase = Phase.Refunding;
            emit PhaseChanged(Phase.Refunding);
        }

        phase = Phase.Refunding;
        emit PhaseChanged(Phase.Refunding);

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NothingToRefund();
        contributions[msg.sender] = 0; // checks-effects-interactions：先改状态再转账

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert RefundFailed();
        emit Refunded(msg.sender, amount);
    }

    // ---------- 治理 ----------

    /// @notice 创建资金使用提案。仅 Funded 阶段可创建。
    function createProposal(string calldata description, address recipient, uint256 amount)
        external
        onlyFunded
        returns (uint256 proposalId)
    {
        if (bytes(description).length == 0) revert InvalidDescription();
        if (recipient == address(0) || recipient == address(this)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (amount > totalRaised - spent) revert InsufficientTreasury(amount, totalRaised - spent);

        proposalId = proposals.length;
        proposals.push(
            Proposal({
                description: description,
                recipient: recipient,
                amount: amount,
                votingEndsAt: uint64(block.timestamp + VOTING_PERIOD),
                votesFor: 0,
                votesAgainst: 0,
                executed: false,
                canceled: false
            })
        );
        emit ProposalCreated(proposalId, recipient, amount, description);
    }

    /// @notice 投票。投票权重 = 当前的出资额（Funded 阶段出资额不再变化，因此无需快照）。
    function vote(uint256 proposalId, bool support) external onlyFunded {
        Proposal storage p = proposals[proposalId];
        if (block.timestamp >= p.votingEndsAt) revert VotingClosed();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        uint256 weight = contributions[msg.sender];
        if (weight == 0) revert NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    /// @notice 执行提案。要求：投票期结束、达到法定人数、赞成票严格多于反对票。
    function execute(uint256 proposalId) external onlyFunded {
        Proposal storage p = proposals[proposalId];
        if (block.timestamp < p.votingEndsAt) revert VotingOpen();
        if (p.executed) revert AlreadyExecuted();
        if (p.canceled) revert AlreadyExecuted();

        uint256 quorum = (totalRaised * QUORUM_NUMERATOR) / QUORUM_DENOMINATOR;
        if (p.votesFor < quorum) revert QuorumNotMet(p.votesFor, quorum);
        if (p.votesFor <= p.votesAgainst) revert ProposalRejected(p.votesFor, p.votesAgainst);
        if (p.amount > totalRaised - spent) revert InsufficientTreasury(p.amount, totalRaised - spent);

        p.executed = true;
        spent += p.amount;

        (bool ok, ) = p.recipient.call{value: p.amount}("");
        require(ok, "transfer failed");
        emit ProposalExecuted(proposalId, p.recipient, p.amount);
    }

    /// @notice 取消提案（任何人可调用，但取消无法恢复已投出的票——见正文讨论）。
    function cancel(uint256 proposalId) external onlyFunded {
        Proposal storage p = proposals[proposalId];
        if (block.timestamp >= p.votingEndsAt) revert VotingClosed();
        if (p.executed) revert AlreadyExecuted();

        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    // ---------- 视图 ----------

    function proposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function treasury() external view returns (uint256) {
        return address(this).balance;
    }

    function availableForProposals() external view returns (uint256) {
        return totalRaised - spent;
    }

    /// @notice 判断提案是否通过（供前端在投票期后调用）。
    function isProposalPassed(uint256 proposalId) external view returns (bool) {
        Proposal storage p = proposals[proposalId];
        uint256 quorum = (totalRaised * QUORUM_NUMERATOR) / QUORUM_DENOMINATOR;
        return !p.executed && !p.canceled && p.votesFor >= quorum && p.votesFor > p.votesAgainst;
    }
}

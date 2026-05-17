// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPredictionMarket {
    function createMarket(
        string memory question,
        uint256 endTime,
        address chainlinkFeed,
        int256 strikePrice
    ) external;

    function resolveMarket(uint256 marketId) external;
}

contract MarketDAO {
    struct MarketProposal {
        string question;
        uint256 endTime;
        address chainlinkFeed;
        int256 strikePrice;

        uint256 createdAt;
        uint256 votingDeadline;

        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool cancelled;
    }

    struct Dispute {
        uint256 marketId;
        address disputor;
        string reason;
        bool resolved;
    }

    IPredictionMarket public predictionMarket;
    address public owner;

    uint256 public proposalCount;
    mapping(uint256 => MarketProposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted; // proposalId => voter => voted

    uint256 public disputeCount;
    mapping(uint256 => Dispute) public disputes;

    event ProposalCreated(
        uint256 indexed proposalId,
        string question,
        uint256 endTime,
        address chainlinkFeed,
        int256 strikePrice,
        uint256 votingDeadline
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support
    );

    event ProposalExecuted(
        uint256 indexed proposalId
    );

    event ProposalCancelled(
        uint256 indexed proposalId
    );

    event DisputeOpened(
        uint256 indexed disputeId,
        uint256 indexed marketId,
        address indexed disputor,
        string reason
    );

    event DisputeResolved(
        uint256 indexed disputeId,
        uint256 indexed marketId
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _predictionMarket) {
        owner = msg.sender;
        predictionMarket = IPredictionMarket(_predictionMarket);
    }

    // ====== ПРОПОЗАЛЫ НА СОЗДАНИЕ РЫНКОВ ======

    /// @notice Создать предложение нового рынка, за которое потом будут голосовать
    function createMarketProposal(
        string memory question,
        uint256 endTime,
        address chainlinkFeed,
        int256 strikePrice,
        uint256 votingDuration
    ) external {
        require(endTime > block.timestamp, "endTime in past");
        require(votingDuration > 0, "votingDuration = 0");

        uint256 proposalId = proposalCount;

        proposals[proposalId] = MarketProposal({
            question: question,
            endTime: endTime,
            chainlinkFeed: chainlinkFeed,
            strikePrice: strikePrice,
            createdAt: block.timestamp,
            votingDeadline: block.timestamp + votingDuration,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            cancelled: false
        });

        proposalCount++;

        emit ProposalCreated(
            proposalId,
            question,
            endTime,
            chainlinkFeed,
            strikePrice,
            block.timestamp + votingDuration
        );
    }

    /// @notice Проголосовать за/против предложения (простое голосование, 1 адрес = 1 голос)
    function voteOnProposal(uint256 proposalId, bool support) external {
        require(proposalId < proposalCount, "proposal does not exist");
        MarketProposal storage p = proposals[proposalId];

        require(block.timestamp <= p.votingDeadline, "voting ended");
        require(!p.cancelled, "cancelled");
        require(!hasVoted[proposalId][msg.sender], "already voted");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.votesFor += 1;
        } else {
            p.votesAgainst += 1;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    /// @notice Выполнить предложение — создать настоящий рынок в PredictionMarket
    /// Вызывает createMarket на PredictionMarket
    function executeProposal(uint256 proposalId) external {
        require(proposalId < proposalCount, "proposal does not exist");
        MarketProposal storage p = proposals[proposalId];

        require(!p.executed, "already executed");
        require(!p.cancelled, "cancelled");
        require(block.timestamp > p.votingDeadline, "voting not ended");
        require(p.votesFor > p.votesAgainst, "not enough support");

        p.executed = true;

        predictionMarket.createMarket(
            p.question,
            p.endTime,
            p.chainlinkFeed,
            p.strikePrice
        );

        emit ProposalExecuted(proposalId);
    }

    /// @notice Владелец DAO может отменить предложение (например, спам)
    function cancelProposal(uint256 proposalId) external onlyOwner {
        require(proposalId < proposalCount, "proposal does not exist");
        MarketProposal storage p = proposals[proposalId];

        require(!p.executed, "already executed");
        require(!p.cancelled, "already cancelled");

        p.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    // ====== СПОРЫ ПО РЫНКАМ ======

    /// @notice Открыть спор по уже существующему рынку
    function openDispute(uint256 marketId, string memory reason) external {
        require(bytes(reason).length > 0, "empty reason");

        uint256 disputeId = disputeCount;

        disputes[disputeId] = Dispute({
            marketId: marketId,
            disputor: msg.sender,
            reason: reason,
            resolved: false
        });

        disputeCount++;

        emit DisputeOpened(disputeId, marketId, msg.sender, reason);
    }

    /// @notice Владелец DAO решает спор и может ещё раз вызвать resolveMarket
    function resolveDispute(uint256 disputeId) external onlyOwner {
        require(disputeId < disputeCount, "dispute does not exist");
        Dispute storage d = disputes[disputeId];

        require(!d.resolved, "already resolved");

        d.resolved = true;

        // опционально: повторное разрешение рынка
        predictionMarket.resolveMarket(d.marketId);

        emit DisputeResolved(disputeId, d.marketId);
    }


    function setPredictionMarket(address _predictionMarket) external onlyOwner {
        predictionMarket = IPredictionMarket(_predictionMarket);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
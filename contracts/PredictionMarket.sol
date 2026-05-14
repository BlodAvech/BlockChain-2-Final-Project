// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOutcomeToken {
    function mintYes(address to, uint256 marketId, uint256 amount) external;
    function mintNo(address to, uint256 marketId, uint256 amount) external;
    function burnYes(address from, uint256 marketId, uint256 amount) external;
    function burnNo(address from, uint256 marketId, uint256 amount) external;
}

interface IFeeVault {
    function depositFees(address token, uint256 amount) external payable;
}

interface AggregatorV3Interface {
    function latestAnswer() external view returns (int256);
}

contract PredictionMarket {
    struct Market {
        string question;
        uint256 endTime;
        bool resolved;
        bool outcome; // true = YES, false = NO
        uint256 yesPool; // ETH в YES
        uint256 noPool;  // ETH в NO
        address chainlinkFeed;
        int256 strikePrice;
    }

    uint256 public constant FEE_BPS = 30; // 0.3%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public owner;
    IOutcomeToken public outcomeToken;
    IFeeVault public feeVault;

    uint256 public marketCount;
    mapping(uint256 => Market) public markets;

    event MarketCreated(
        uint256 indexed marketId,
        string question,
        uint256 endTime,
        address chainlinkFeed,
        int256 strikePrice
    );

    event BoughtYes(
        uint256 indexed marketId,
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );

    event BoughtNo(
        uint256 indexed marketId,
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );

    event MarketResolved(uint256 indexed marketId, bool outcome);

    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 payout
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(marketId < marketCount, "market does not exist");
        _;
    }

    modifier beforeEnd(uint256 marketId) {
        require(block.timestamp < markets[marketId].endTime, "market ended");
        _;
    }

    modifier afterEnd(uint256 marketId) {
        require(block.timestamp >= markets[marketId].endTime, "market not ended");
        _;
    }

    constructor(address _outcomeToken, address _feeVault) {
        owner = msg.sender;
        outcomeToken = IOutcomeToken(_outcomeToken);
        feeVault = IFeeVault(_feeVault);
    }

    function createMarket(
        string memory question,
        uint256 endTime,
        address chainlinkFeed,
        int256 strikePrice
    ) external onlyOwner {
        require(endTime > block.timestamp, "endTime in the past");

        uint256 marketId = marketCount;

        markets[marketId] = Market({
            question: question,
            endTime: endTime,
            resolved: false,
            outcome: false,
            yesPool: 0,
            noPool: 0,
            chainlinkFeed: chainlinkFeed,
            strikePrice: strikePrice
        });

        marketCount++;

        emit MarketCreated(marketId, question, endTime, chainlinkFeed, strikePrice);
    }

    function buyYes(uint256 marketId, uint256 amount)
        external
        payable
        marketExists(marketId)
        beforeEnd(marketId)
    {
        require(amount > 0, "amount = 0");
        Market storage m = markets[marketId];

        uint256 cost = _quoteBuyYes(m, amount);
        uint256 fee = (cost * FEE_BPS) / BPS_DENOMINATOR;
        uint256 total = cost + fee;

        require(msg.value >= total, "insufficient ETH");

        m.yesPool += cost;

        if (fee > 0) {
            feeVault.depositFees{value: fee}(address(0), fee);
        }

        if (msg.value > total) {
            (bool refundOk, ) = msg.sender.call{value: msg.value - total}("");
            require(refundOk, "refund failed");
        }

        outcomeToken.mintYes(msg.sender, marketId, amount);

        emit BoughtYes(marketId, msg.sender, amount, cost);
    }

    function buyNo(uint256 marketId, uint256 amount)
        external
        payable
        marketExists(marketId)
        beforeEnd(marketId)
    {
        require(amount > 0, "amount = 0");
        Market storage m = markets[marketId];

        uint256 cost = _quoteBuyNo(m, amount);
        uint256 fee = (cost * FEE_BPS) / BPS_DENOMINATOR;
        uint256 total = cost + fee;

        require(msg.value >= total, "insufficient ETH");

        m.noPool += cost;

        if (fee > 0) {
            feeVault.depositFees{value: fee}(address(0), fee);
        }

        if (msg.value > total) {
            (bool refundOk, ) = msg.sender.call{value: msg.value - total}("");
            require(refundOk, "refund failed");
        }

        outcomeToken.mintNo(msg.sender, marketId, amount);

        emit BoughtNo(marketId, msg.sender, amount, cost);
    }

    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (Market memory)
    {
        return markets[marketId];
    }

    function getAllMarkets() external view returns (Market[] memory) {
        Market[] memory all = new Market[](marketCount);
        for (uint256 i = 0; i < marketCount; i++) {
            all[i] = markets[i];
        }
        return all;
    }

    function resolveMarket(uint256 marketId)
        external
        marketExists(marketId)
        afterEnd(marketId)
    {
        Market storage m = markets[marketId];
        require(!m.resolved, "already resolved");
        require(m.chainlinkFeed != address(0), "no oracle set");

        require(block.timestamp > m.endTime + 1 days, "dispute window not passed");

        int256 price = AggregatorV3Interface(m.chainlinkFeed).latestAnswer();

        m.resolved = true;
        m.outcome = price > m.strikePrice;

        emit MarketResolved(marketId, m.outcome);
    }

    function claimWinnings(uint256 marketId, uint256 amountYes, uint256 amountNo)
        external
        marketExists(marketId)
        afterEnd(marketId)
    {
        Market storage m = markets[marketId];
        require(m.resolved, "not resolved");
        require(amountYes > 0 || amountNo > 0, "nothing to claim");

        uint256 payout;

        if (m.outcome) {
            if (amountYes > 0) {
                uint256 totalYes = m.yesPool;
                require(totalYes > 0, "no YES pool");
                uint256 share = (m.yesPool + m.noPool) * amountYes / totalYes;

                outcomeToken.burnYes(msg.sender, marketId, amountYes);
                payout += share;
            }
            if (amountNo > 0) {
                outcomeToken.burnNo(msg.sender, marketId, amountNo);
            }
        } else {
            if (amountNo > 0) {
                uint256 totalNo = m.noPool;
                require(totalNo > 0, "no NO pool");
                uint256 share = (m.yesPool + m.noPool) * amountNo / totalNo;

                outcomeToken.burnNo(msg.sender, marketId, amountNo);
                payout += share;
            }
            if (amountYes > 0) {
                outcomeToken.burnYes(msg.sender, marketId, amountYes);
            }
        }

        require(payout > 0, "payout = 0");

        (bool ok, ) = msg.sender.call{value: payout}("");
        require(ok, "transfer failed");

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    function _quoteBuyYes(Market storage m, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 newYes = m.yesPool + amount;
        uint256 total = newYes + m.noPool;
        if (total == 0) {
            return amount;
        }
        return (newYes * amount) / total;
    }

    function _quoteBuyNo(Market storage m, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 newNo = m.noPool + amount;
        uint256 total = m.yesPool + newNo;
        if (total == 0) {
            return amount;
        }
        return (newNo * amount) / total;
    }

    function setOutcomeToken(address _outcomeToken) external onlyOwner {
        outcomeToken = IOutcomeToken(_outcomeToken);
    }

    function setFeeVault(address _feeVault) external onlyOwner {
        feeVault = IFeeVault(_feeVault);
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    receive() external payable {}
}
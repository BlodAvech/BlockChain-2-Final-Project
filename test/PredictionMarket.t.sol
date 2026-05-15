// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contract/PredictionMarket.sol";
import "../contract/OutcomeToken.sol";
import "../contract/FeeVault.sol";

contract PredictionMarketTest is Test {
    PredictionMarket market;
    OutcomeToken outcomeToken;
    FeeVault feeVault;

    address owner = address(this);
    address user = address(0x123);

    function setUp() public {
        outcomeToken = new OutcomeToken(
            "Outcome Shares",
            "OUT",
            "https://example.com/{id}.json",
            address(this)
        );

        feeVault = new FeeVault();

        market = new PredictionMarket(
            address(outcomeToken),
            address(feeVault)
        );

        outcomeToken.setPredictionMarket(address(market));

        vm.deal(user, 10 ether);
    }

    function testCreateMarket() public {
        uint256 endTime = block.timestamp + 1 days;

        market.createMarket(
            "Will BTC be above 100k?",
            endTime,
            address(0x1111),
            100000
        );

        assertEq(market.marketCount(), 1);

        (
            string memory question,
            uint256 returnedEndTime,
            bool resolved,
            bool outcome,
            uint256 yesPool,
            uint256 noPool,
            address chainlinkFeed,
            int256 strikePrice
        ) = market.markets(0);

        assertEq(question, "Will BTC be above 100k?");
        assertEq(returnedEndTime, endTime);
        assertEq(resolved, false);
        assertEq(outcome, false);
        assertEq(yesPool, 0);
        assertEq(noPool, 0);
        assertEq(chainlinkFeed, address(0x1111));
        assertEq(strikePrice, 100000);
    }

    function testBuyYes() public {
        uint256 endTime = block.timestamp + 1 days;

        market.createMarket(
            "Will ETH be above 5k?",
            endTime,
            address(0x2222),
            5000
        );

        vm.prank(user);
        market.buyYes{value: 2 ether}(0, 1 ether);

        (
            ,
            ,
            ,
            ,
            uint256 yesPool,
            uint256 noPool,
            ,

        ) = market.markets(0);

        assertGt(yesPool, 0);
        assertEq(noPool, 0);

        uint256 yesTokenId = outcomeToken.yesId(0);
        uint256 balance = outcomeToken.balanceOf(user, yesTokenId);

        assertEq(balance, 1 ether);
    }
}
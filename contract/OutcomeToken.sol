// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract OutcomeToken is ERC1155, Ownable {
    string public name;
    string public symbol;

    address public predictionMarket; // контракт PredictionMarket, которому доверяем минт/берн

    error NotPredictionMarket();

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _initialOwner
    ) 
        ERC1155(_uri)
        Ownable(_initialOwner) 
    {
        name = _name;
        symbol = _symbol;
    }

    modifier onlyPredictionMarket() {
        if (msg.sender != predictionMarket) revert NotPredictionMarket();
        _;
    }

    function setPredictionMarket(address _predictionMarket) external onlyOwner {
        predictionMarket = _predictionMarket;
    }

    // YES: marketId * 2
    // NO:  marketId * 2 + 1

    function yesId(uint256 marketId) public pure returns (uint256) {
        return marketId * 2;
    }

    function noId(uint256 marketId) public pure returns (uint256) {
        return marketId * 2 + 1;
    }

    function mintYes(address to, uint256 marketId, uint256 amount)
        external
        onlyPredictionMarket
    {
        _mint(to, yesId(marketId), amount, "");
    }

    function mintNo(address to, uint256 marketId, uint256 amount)
        external
        onlyPredictionMarket
    {
        _mint(to, noId(marketId), amount, "");
    }

    function burnYes(address from, uint256 marketId, uint256 amount)
        external
        onlyPredictionMarket
    {
        _burn(from, yesId(marketId), amount);
    }

    function burnNo(address from, uint256 marketId, uint256 amount)
        external
        onlyPredictionMarket
    {
        _burn(from, noId(marketId), amount);
    }
}
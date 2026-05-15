// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FeeVault {
    address public owner;

    event FeesDeposited(address indexed token, uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function depositFees(address token, uint256 amount) external payable {
        token; amount; // игнорируем, чтобы не было warning
        require(msg.value > 0, "no value");
        emit FeesDeposited(address(0), msg.value);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "transfer failed");
        emit FeesWithdrawn(to, amount);
    }

    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contract/FeeVault.sol";

contract FeeVaultTest is Test {
    FeeVault feeVault;

    address owner = address(this);
    address user = address(0x456);
    address receiver = address(0x789);

    function setUp() public {
        feeVault = new FeeVault();
        vm.deal(user, 5 ether);
    }

    function testDepositFees() public {
        vm.prank(user);
        feeVault.depositFees{value: 1 ether}(address(0), 1 ether);

        assertEq(address(feeVault).balance, 1 ether);
    }

    function testWithdrawFees() public {
        vm.prank(user);
        feeVault.depositFees{value: 2 ether}(address(0), 2 ether);

        uint256 receiverBalanceBefore = receiver.balance;

        feeVault.withdraw(payable(receiver), 1 ether);

        assertEq(address(feeVault).balance, 1 ether);
        assertEq(receiver.balance, receiverBalanceBefore + 1 ether);
    }
}

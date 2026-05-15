// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contract/OutcomeToken.sol";
import "../contract/FeeVault.sol";
import "../contract/PredictionMarket.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        OutcomeToken outcomeToken = new OutcomeToken(
            "Market Shares",
            "MSh",
            "ipfs://bafybeich7ovq32lyj54k762orzz7yhef73a3zmydc45xj2i2m2om5q3mfa/{id}.json",
            deployer
        );

        FeeVault feeVault = new FeeVault();

        PredictionMarket predictionMarket = new PredictionMarket(address(outcomeToken), address(feeVault));

        outcomeToken.setPredictionMarket(address(predictionMarket));

        vm.stopBroadcast();
    }
}

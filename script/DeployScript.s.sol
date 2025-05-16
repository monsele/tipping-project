// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CoffeeNFTImplementation.sol";
//import "../src/MintMeACoffeeFactory.sol";
import {MintMeACoffeeFactory} from "../src/MintMeACoffeeFactory.sol";

contract DeployScript is Script {
    function run() external {
        // Start broadcasting transactions to the network
        vm.startBroadcast();

        // 1. Deploy the implementation contract first
        CoffeeNFTImplementation implementation = new CoffeeNFTImplementation("https://myapp.com/{id}");
        console.log("CoffeeNFTImplementation deployed at:", address(implementation));

        // 2. Deploy the factory contract with the implementation address
        MintMeACoffeeFactory factory = new MintMeACoffeeFactory(address(implementation));
        console.log("MintMeACoffeeFactory deployed at:", address(factory));

        // 3. Creating a contract for creator1 (optional, can be done separately)
        address creator1 = 0x49abF65f5c9F13Ba55280Ab7E304dDA06cD718cf; // Replace with actual address
        address creator1Contract = factory.createCoffeeContract("Creator1 Coffee Collection", "C1COFFEE", creator1);
        console.log("Creator1 contract deployed at:", creator1Contract);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Note: The following steps would typically be done by the creator and users later,
        // not in the deployment script. They are shown here for reference.

        console.log("Next steps would be:");
        console.log("4. Creator adds coffee designs to their contract:");
        console.log("   CoffeeNFTImplementation(creator1Contract).addCoffeeDesign(");
        console.log("       \"ipfs://QmYx45...\", // IPFS URI to the NFT metadata");
        console.log("       0.01 ether,         // Price per coffee (0.01 ETH)");
        console.log("       0x5678...,          // Artist address");
        console.log("       1000                // 10% royalty for the artist");
        console.log("   );");

        console.log("5. Users can mint coffee NFTs to tip the creator:");
        console.log("   CoffeeNFTImplementation(creator1Contract).mintCoffee{value: 0.01 ether}(");
        console.log("       1,  // tokenId");
        console.log("       1   // amount");
        console.log("   );");
    }
}

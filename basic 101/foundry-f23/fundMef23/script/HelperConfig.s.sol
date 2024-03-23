// SPDX-License-Identifier: MIT

// Deploy mocks when we are on local anvil chain!
// keep track of contract addresses across diffrent chains
// Sepolia ETH/USD -> diffrent address
// Mainnet ETH/USD -> diffrent address

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    // If we are on a local anvil we deploy mocks
    // Otherwise, grab the existing address from the live network
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address priceFeed; // ETH/USD -> priceFeed Address
    }

    // constructor
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if(block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        }
        
        else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    // prlm

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        // price feed address
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

     function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        // price feed address
        NetworkConfig memory ethConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return ethConfig;
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        // price feed address

        // deploy the mocks 
        // return the mock addresses
        vm.startBroadcast();
MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 2000e8);
        vm.startBroadcast();
NetworkConfig memory anvilConfig = NetworkConfig({
    priceFeed: address(mockPriceFeed)
});
return anvilConfig;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/DigitalTwins.sol";

contract DeployDigitalTwins is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = 0xeD3eB6b8d6440029908a865B888EeD8c63ad468b; // Gnosis-Safe
        // -------- Constructor ARGS --------

        vm.startBroadcast(deployerPrivateKey);

        DigitalTwins digitalTwins = new DigitalTwins("", relayer);
        digitalTwins.setMintActive(true);
        digitalTwins.setNftPrice(0.01 ether);
        vm.stopBroadcast();
    }
}

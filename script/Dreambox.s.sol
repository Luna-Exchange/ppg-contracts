// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/Dreambox.sol";

contract DeployDreambox is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory uri = "https://test-uri";
        // -------- Constructor ARGS --------

        vm.startBroadcast(deployerPrivateKey);

        Dreambox dreambox = new Dreambox(uri);

        vm.stopBroadcast();
    }
}

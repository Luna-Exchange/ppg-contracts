// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/Dreambox.sol";

contract DeployDreambox is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory uri = "ipfs://bafybeicbdypzqaz2y7gh6v526ojb2y3ckyw6tm3lcgiz365pcg6evuele4/ppg.dreambox/{id}.json";
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;
        address tokenReceiver = 0x3203617C22D58652Bbc12B2F6BD5566c365ea0d4;
        // -------- Constructor ARGS --------

        vm.startBroadcast(deployerPrivateKey);

        Dreambox dreambox = new Dreambox(tokenReceiver, amounts, uri);

        vm.stopBroadcast();
    }
}

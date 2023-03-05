// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/PlayPopGo.sol";

contract DeployPlayPopGo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // -------- Constructor ARGS --------
        address withdrawAddress = 0x4401A1667dAFb63Cff06218A69cE11537de9A101;
        address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
        string memory preRevealURI = "https://prereveal/";
        string memory postRevealedURI = "https://postreveal/";
        uint256 maxSupply = 4;
        uint256 mintCost = 0.01 ether;
        uint64 vrfSubscriptionId = 3414;
        bytes32 vrfGasLane = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
        uint32 vrfCallbackGasLimit = 100000;

        vm.startBroadcast(deployerPrivateKey);

        PlayPopGo PlayPopGo = new PlayPopGo(
            withdrawAddress,
            preRevealURI,
            postRevealedURI,
            maxSupply,
            mintCost,
            address(vrfCoordinator),
            vrfSubscriptionId,
            vrfGasLane,
            vrfCallbackGasLimit
        );

        vm.stopBroadcast();
    }
}

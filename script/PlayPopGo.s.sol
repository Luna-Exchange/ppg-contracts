// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/PlayPopGo.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // -------- Constructor ARGS --------
        address vrfCoordinator;
        address withdrawAddress;
        string memory baseURI = "https://baseURI/";
        string memory unrevealedURI;
        uint256 maxSupply;
        uint256 mintCost;
        uint64 vrfSubscriptionId;
        bytes32 vrfGasLane;
        uint32 vrfCallbackGasLimit;

        vm.startBroadcast(deployerPrivateKey);

        PlayPopGo PlayPopGo = new PlayPopGo(
            withdrawAddress,
            baseURI,
            unrevealedURI,
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

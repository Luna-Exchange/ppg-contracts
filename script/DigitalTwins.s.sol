// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/DigitalTwins.sol";

contract DeployDigitalTwins is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = 0xdA179bd337b0828Ed874A32196de3f4b00E1D446; // Gnosis-Safe
        address payable feeRecipient = payable(0x8D6A3B0541d73e77A6ba0C7440054a8997457FE2);
        // -------- Constructor ARGS --------

        vm.startBroadcast(deployerPrivateKey);

        DigitalTwins digitalTwins = new DigitalTwins("ipfs://QmeuhcgHXsesZxdiSPdsag6XtsmNGWfDAke76SY4krkdcB/", relayer, feeRecipient);
        digitalTwins.setMintActive(true);
        digitalTwins.setNftPrice(78.95 ether);
        vm.stopBroadcast();
    }
}

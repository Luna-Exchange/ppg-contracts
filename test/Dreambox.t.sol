// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Dreambox.sol";
import {MerkleTree} from "./utils/MerkleTree/MerkleTree.sol";

contract DreamboxTest is Test {
    MerkleTree public mt;
    Dreambox dreambox;
    address deployer;
    address owner;
    address minter1;
    address minter2;
    address minter3;
    address minter4;

    function setUp() public {
        deployer = makeAddr("deployer");
        owner = makeAddr("owner");
        minter1 = makeAddr("minter1");
        minter2 = makeAddr("minter2");
        minter3 = makeAddr("minter3");
        minter4 = makeAddr("minter4");
        vm.deal(owner, 100 ether);
        vm.deal(minter1, 100 ether);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;

        vm.prank(deployer);
        dreambox = new Dreambox(deployer, amounts, "https://test-uri");
        mt = new MerkleTree(false, true, true);

        bytes32 hashedminter1 = keccak256(abi.encodePacked(minter1));
        bytes32 hashedminter2 = keccak256(abi.encodePacked(minter2));
        bytes32 hashedminter3 = keccak256(abi.encodePacked(minter3));
        bytes32 hashedminter4 = keccak256(abi.encodePacked(minter4));
        mt.addLeaf(hashedminter1, false);
        mt.addLeaf(hashedminter2, false);
        mt.addLeaf(hashedminter3, false);
        mt.addLeaf(hashedminter4, false);
    }

    function test_dreamboxMint() public {
        bytes32[] memory proof = mt.getProof(keccak256(abi.encodePacked(minter1)));
        vm.startPrank(deployer);
        dreambox.activateMint();
        dreambox.setRoot(mt.getRoot());
        vm.stopPrank();
        vm.prank(minter1, address(minter1));
        dreambox.mint(proof);
    }
}

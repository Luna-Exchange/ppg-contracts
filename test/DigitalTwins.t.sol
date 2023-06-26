// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/DigitalTwins.sol";


contract DigitalTwinsTest is Test {
    DigitalTwins digitalTwins;
    address relayer;
    address owner;
    address minter1;
    address minter2;
    address minter3;
    address minter4;

    function setUp() public {
        relayer = makeAddr("relayer");
        owner = makeAddr("owner");
        minter1 = makeAddr("minter1");
        minter2 = makeAddr("minter2");
        minter3 = makeAddr("minter3");
        minter4 = makeAddr("minter4");
        vm.deal(owner, 100 ether);
        vm.deal(minter1, 100 ether);
        vm.deal(minter2, 100 ether);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;

        vm.startPrank(owner);
        digitalTwins = new DigitalTwins("https://test-uri/", relayer);
        digitalTwins.setNftPrice(0.1 ether);
        vm.stopPrank();
    }
    
    function test_revertMintWhen_mintActivity_false() public {
        vm.expectRevert(MintIsNotActive.selector);
        vm.prank(minter1);
        digitalTwins.mint(minter1, 0, 1, 100);
    }

    function test_revertMintWhen_notEnoughMoney() public {
        vm.prank(owner);
        digitalTwins.setMintActive(true);
        vm.expectRevert(NotEnoughMoneyToBuyNft.selector);
        vm.prank(minter1);
        digitalTwins.mint{value: 1 ether}(minter1, 0, 1, 100);
    }

    function test_revertMintWhen_relayerTryDoubleClaim() public {
        vm.prank(owner);
        digitalTwins.setMintActive(true);
        vm.startPrank(relayer);
        digitalTwins.mint{value: 0 ether}(minter2, 1,  1, 100);
        assertEq(digitalTwins.balanceOf(minter2, 1), 100);
        vm.expectRevert(AlreadyClaimed.selector);
        digitalTwins.mint(minter2, 1,  1, 100);
    }

    function test_digitalTwinsMint() public {
        vm.prank(owner);
        digitalTwins.setMintActive(true);
        vm.startPrank(minter1);
        digitalTwins.mint{value: 10 ether}(minter1, 0, 1, 100);
        assertEq(digitalTwins.balanceOf(minter1, 1), 100);
        digitalTwins.mint{value: 10 ether}(minter1, 0, 1, 100);
        assertEq(digitalTwins.balanceOf(minter1, 1), 200);
        digitalTwins.mint{value: 5 ether}(minter1, 0, 2, 50);
        assertEq(digitalTwins.balanceOf(minter1, 2), 50);
        vm.stopPrank();

        vm.prank(minter2);
        digitalTwins.mint{value: 10 ether}(minter2, 0, 1, 100);
        assertEq(digitalTwins.balanceOf(minter2, 1), 100);
    }
}

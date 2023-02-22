// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {Clothes} from "../src/Clothes.sol";

contract ClothesTest is Test {
    Clothes clothes;
    address deployer;
    address owner;
    address minter2;
    address withdrawAddress;
    uint256[] ids;
    uint256[] amounts;

    function setUp() public {
        deployer = makeAddr("deployer");
        owner = makeAddr("owner");
        minter2 = makeAddr("minter2");
        vm.deal(owner, 100 ether);
        vm.deal(owner, 100 ether);
        vm.deal(minter2, 100 ether);

        ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        amounts = [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
    }

    function test_mintOnDeploy(string memory uri, bytes memory data) public {
        clothes = new Clothes(uri, owner, ids, amounts, data);
        assertEq(clothes.balanceOf(owner, 1), 1000);
        assertEq(clothes.balanceOf(owner, 2), 1000);
        assertEq(clothes.balanceOf(owner, 3), 1000);
        assertEq(clothes.balanceOf(owner, 4), 1000);
        assertEq(clothes.balanceOf(owner, 5), 1000);
        assertEq(clothes.balanceOf(owner, 6), 1000);
        assertEq(clothes.balanceOf(owner, 7), 1000);
        assertEq(clothes.balanceOf(owner, 8), 1000);
        assertEq(clothes.balanceOf(owner, 9), 1000);
        assertEq(clothes.balanceOf(owner, 10), 1000);
    }
}

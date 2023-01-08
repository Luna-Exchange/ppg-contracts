// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PlayPopGo} from "../src/PlayPopGo.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import {MerkleTree} from "./utils/MerkleTree/MerkleTree.sol";

contract PlayPopGoTest is Test {
    PlayPopGo playPopGo;
    address owner;
    address minter;

    // ---------- CONSTRUCTOR ARGS ----------
    string public baseURI = "https://baseURI/";
    string public name = "PlayPopGo";
    string public symbol = "PPG";
    uint256 public maxSupply = 10000;
    uint256 public mintCost = 0.1 ether;
    uint64 vrfSubscriptionId = 5;
    address vrfCoordinatorV2 =
        address(0x0000000000000000000000000000000000000009);
    bytes32 vrfGaLane = bytes32("gaslane");
    uint32 vrfCallbackGasLimit = 1000000;

    // ---------- MERKLE TREE ----------
    MerkleTree public mt;
    bytes32 root;
    bytes32[] proof;

    function setUp() public {
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        vm.deal(owner, 100 ether);
        vm.deal(minter, 100 ether);

        vm.prank(owner);
        playPopGo = new PlayPopGo(
            baseURI,
            name,
            symbol,
            maxSupply,
            mintCost,
            vrfCoordinatorV2,
            vrfSubscriptionId,
            vrfGaLane,
            vrfCallbackGasLimit
        );

        // Merkle-Tree
        mt = new MerkleTree(false, false, false);
        bytes32 hashedOwner = keccak256(abi.encodePacked(owner));
        bytes32 hashedMinter = keccak256(abi.encodePacked(minter));
        mt.addLeaf(hashedOwner, false);
        mt.addLeaf(hashedMinter, false);
        root = mt.getRoot();
        proof = mt.getProof(hashedMinter);
    }

    /*//////////////////////////////////////////////////////////////
                            privateMint TESTS
    //////////////////////////////////////////////////////////////*/

    function test_privateMint() public {
        vm.prank(owner);
        playPopGo.setDreamBoxRoot(root);

        vm.prank(minter);
        playPopGo.privateMint(proof);
        assertEq(playPopGo.balanceOf(minter), 1);
    }

    /*//////////////////////////////////////////////////////////////
                            publicMint TESTS
    //////////////////////////////////////////////////////////////*/

    function test_publicMint() public {
        vm.prank(minter);
        playPopGo.publicMint{value: 0.5 ether}(5);
        assertEq(playPopGo.balanceOf(minter), 5);
    }

    function test_publicMintInvalidAmount() public {
        vm.startPrank(minter);
        vm.expectRevert(PlayPopGo.InvalidAmount.selector);
        playPopGo.publicMint(0);
    }

    function test_publicMintMaxMintPerAddressSurpassed() public {
        vm.startPrank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                PlayPopGo.MaxMintPerAddressSurpassed.selector,
                9999,
                5
            )
        );
        playPopGo.publicMint(9999);
    }

    function test_publicMintMaxSupplyReached() public {
        vm.startPrank(minter);
        vm.expectRevert(PlayPopGo.MaxSupplyReached.selector);
        playPopGo.publicMint(10001);
    }

    function test_publicMintInsufficientFunds() public {
        vm.startPrank(minter);
        vm.expectRevert(PlayPopGo.InsufficientFunds.selector);
        playPopGo.publicMint(1);
    }

    function test_name() public {
        assertEq(playPopGo.name(), name);
    }

    function test_symbol() public {
        assertEq(playPopGo.symbol(), symbol);
    }

    function test_setBaseURI() public {
        vm.startPrank(minter);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setBaseURI("https://newBaseURI/");
        vm.stopPrank();

        vm.prank(owner);
        playPopGo.setBaseURI("https://newBaseURI/");
        assertEq(playPopGo._uri(), "https://newBaseURI/");
    }

    function test_tokenURI() public {
        vm.startPrank(minter);

        // Reverts if no token has been minted
        vm.expectRevert(bytes4(keccak256("NonExistentToken()")));
        playPopGo.tokenURI(1);

        // Mints a token and checks the tokenURI is correct
        playPopGo.publicMint{value: 0.1 ether}(1);
        string memory tokenURI = playPopGo.tokenURI(1);
        assertEq(tokenURI, "https://baseURI/1.json");

        vm.stopPrank();
    }
}

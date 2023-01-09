// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PlayPopGo} from "../src/PlayPopGo.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import {MerkleTree} from "./utils/MerkleTree/MerkleTree.sol";
import {VRFCoordinatorV2Mock} from "./utils/mocks/VRFCoordinatorV2Mock.sol";
import {LinkTokenMock} from "./utils/mocks/LinkTokenMock.sol";

contract PlayPopGoTest is Test {
    PlayPopGo playPopGo;
    VRFCoordinatorV2Mock vrfCoordinator;
    LinkTokenMock linkToken;

    address owner;
    address minter;

    // ---------- CONSTRUCTOR ARGS ----------
    string public baseURI = "https://baseURI/";
    string public name = "PlayPopGo";
    string public symbol = "PPG";
    string public unrevealedURI = "https://unrevealedURI/";
    uint256 public maxSupply = 10000;
    uint256 public mintCost = 0.1 ether;
    uint64 vrfSubscriptionId = 5;
    bytes32 vrfGasLane = bytes32("gaslane");
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

        vm.startPrank(owner);
        linkToken = new LinkTokenMock();
        vrfCoordinator = new VRFCoordinatorV2Mock(10 * 3, 10 * 3);
        playPopGo = new PlayPopGo(
            baseURI,
            name,
            symbol,
            unrevealedURI,
            maxSupply,
            mintCost,
            address(vrfCoordinator),
            vrfSubscriptionId,
            vrfGasLane,
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
        vm.stopPrank();
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
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.MaxMintPerAddressSurpassed.selector, 9999, 5));
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

    /*//////////////////////////////////////////////////////////////
                            tokenURI TESTS
    //////////////////////////////////////////////////////////////*/

    function test_tokenURINonExistentToken() public {
        vm.startPrank(minter);

        // Reverts if no token has been minted
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.NonExistentToken.selector));
        playPopGo.tokenURI(1);
    }

    function test_tokenURIUnrevealed() public {
        // Mints a token and checks the tokenURI is correct
        vm.startPrank(minter);
        playPopGo.publicMint{value: 0.1 ether}(1);
        string memory tokenURI = playPopGo.tokenURI(1);
        assertEq(tokenURI, unrevealedURI);
        vm.stopPrank();
    }

    function test_tokenURIRevealed() public {
        // Start off by requesting random offset
        vm.prank(owner);
        uint256 requestId = playPopGo.requestRandomOffset();
        // Create a uint256 array and push 100
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 9998;
        vrfCoordinator.fulfillRandomWords(requestId, address(playPopGo), randomWords);

        // Mints a token and checks the tokenURI is correct
        vm.prank(minter);
        playPopGo.publicMint{value: 0.3 ether}(3);

        string memory tokenURI1 = playPopGo.tokenURI(1);
        assertEq(tokenURI1, "https://baseURI/9999.json");
        string memory tokenURI2 = playPopGo.tokenURI(2);
        assertEq(tokenURI2, "https://baseURI/0.json");
        string memory tokenURI3 = playPopGo.tokenURI(3);
        assertEq(tokenURI3, "https://baseURI/1.json");
    }
}

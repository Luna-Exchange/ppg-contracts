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
    address minter1;
    address minter2;
    address withdrawAddress;

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
    bytes32[] proof1;
    bytes32[] proof2;

    // ---------- EVENTS ----------
    event DreamboxRootUpdated(bytes32 dreamBoxRoot);

    function setUp() public {
        withdrawAddress = makeAddr("withdrawAddress");
        owner = makeAddr("owner");
        minter1 = makeAddr("minter1");
        minter2 = makeAddr("minter2");
        vm.deal(owner, 100 ether);
        vm.deal(minter1, 100 ether);
        vm.deal(minter2, 100 ether);

        vm.startPrank(owner);
        linkToken = new LinkTokenMock();
        vrfCoordinator = new VRFCoordinatorV2Mock(10 * 3, 10 * 3);
        playPopGo = new PlayPopGo(
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

        // Merkle-Tree
        mt = new MerkleTree(false, false, false);
        bytes32 hashedminter1 = keccak256(abi.encodePacked(minter1));
        bytes32 hashedminter2 = keccak256(abi.encodePacked(minter2));
        mt.addLeaf(hashedminter1, false);
        mt.addLeaf(hashedminter2, false);
        root = mt.getRoot();
        proof1 = mt.getProof(hashedminter1);
        proof2 = mt.getProof(hashedminter2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            setters TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setBaseUri(string memory _newBaseURI) public {
        vm.prank(owner);
        playPopGo.setBaseURI(_newBaseURI);
        assertEq(playPopGo._uri(), _newBaseURI);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setBaseURI(_newBaseURI);
    }

    function setMaxSupply(uint256 _maxSupply) public {
        vm.prank(owner);
        playPopGo.setMaxSupply(_maxSupply);
        assertEq(playPopGo._maxSupply(), _maxSupply);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setMaxSupply(_maxSupply);

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
    }

    function setPreRevealURI(string memory _preRevealURI) public {
        vm.prank(owner);
        playPopGo.setPreRevealURI(_preRevealURI);
        assertEq(playPopGo._preRevealURI(), _preRevealURI);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setPreRevealURI(_preRevealURI);
    }

    function setSaleStatus() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        vm.stopPrank();

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
    }

    function setDreamboxRoot(bytes32 _dreamBoxRoot) public {
        vm.startPrank(owner);
        playPopGo.setDreamboxRoot(_dreamBoxRoot);
        assertEq(playPopGo._dreamBoxRoot(), _dreamBoxRoot);

        vm.expectEmit(true, true, true, true);
        emit DreamboxRootUpdated("hello");
        playPopGo.setDreamboxRoot("bye");
        // TODO: Check the implementatino of this

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setDreamboxRoot(_dreamBoxRoot);
    }

    function test_withdrawFunds() public {
        assertEq(withdrawAddress.balance, 0 ether);
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.2 ether}(2);

        vm.prank(owner);
        playPopGo.withdrawFunds();
        assertEq(withdrawAddress.balance, 0.2 ether);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.withdrawFunds();
    }

    /*//////////////////////////////////////////////////////////////
                            startReveal TESTS
    //////////////////////////////////////////////////////////////*/

    function test_startReveal() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.2 ether}(2);

        vm.prank(owner);
        playPopGo.startReveal();
        assertEq(playPopGo._revealed(), true);

        vm.prank(owner);
        vm.expectRevert(PlayPopGo.AlreadyRevealed.selector);
        playPopGo.startReveal();

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.startReveal();
    }

    /*//////////////////////////////////////////////////////////////
                            publicMint TESTS
    //////////////////////////////////////////////////////////////*/

    function test_publicMint() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);
        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.2 ether}(2);
        assertEq(playPopGo.balanceOf(minter1), 2);
    }

    function test_publicMintSaleIsNotOpen() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PAUSED);
        vm.prank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.publicMint{value: 0.2 ether}(2);

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.publicMint{value: 0.2 ether}(2);

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.publicMint{value: 0.2 ether}(2);
    }

    function test_publicMintInvalidAmount() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);
        vm.startPrank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.InvalidAmount.selector);
        playPopGo.publicMint(0);
    }

    function test_publicMintMaxSupplyReached() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);
        vm.startPrank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.MaxSupplyReached.selector);
        playPopGo.publicMint(10001);
    }

    function test_publicMintInsufficientFunds() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);
        vm.startPrank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.InsufficientFunds.selector);
        playPopGo.publicMint(1);
    }

    function test_publicMintMaxMintPerAddressSurpassed() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);
        vm.startPrank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.2 ether}(2);
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.MaxMintPerAddressSurpassed.selector, 2, 2));
        playPopGo.publicMint{value: 90 ether}(99);
    }

    /*//////////////////////////////////////////////////////////////
                            dreamboxMint TESTS
    //////////////////////////////////////////////////////////////*/

    function test_dreamboxMint() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        playPopGo.setDreamboxRoot(root);
        vm.stopPrank();

        vm.prank(minter1, address(minter1));
        playPopGo.dreamboxMint(proof1);
        assertEq(playPopGo.balanceOf(minter1), 1);

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);

        vm.prank(minter2, address(minter2));
        playPopGo.dreamboxMint(proof2);
        assertEq(playPopGo.balanceOf(minter2), 1);
    }

    function test_dreamboxMintSaleIsNotOpen() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PAUSED);

        vm.prank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.dreamboxMint(proof1);

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);

        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.dreamboxMint(proof2);
    }

    function test_dreamboxMintDreamboxMintUsed() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        playPopGo.setDreamboxRoot(root);
        vm.stopPrank();

        vm.startPrank(minter1, address(minter1));
        playPopGo.dreamboxMint(proof1);
        assertEq(playPopGo.balanceOf(minter1), 1);

        vm.expectRevert(PlayPopGo.DreamboxMintUsed.selector);
        playPopGo.dreamboxMint(proof1);
    }

    function test_dreamboxMintMaxSupplyReached() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        playPopGo.setMaxSupply(1);
        playPopGo.setDreamboxRoot(root);
        vm.stopPrank();

        vm.prank(minter1, address(minter1));
        playPopGo.dreamboxMint(proof1);

        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.MaxSupplyReached.selector);
        playPopGo.dreamboxMint(proof2);
    }

    function test_dreamboxMintInvalidMerkleProof() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        playPopGo.setDreamboxRoot(root);
        vm.stopPrank();

        vm.prank(minter1, address(minter1));
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.InvalidMerkleProof.selector, minter1, proof2));
        playPopGo.dreamboxMint(proof2);
    }

    // /*//////////////////////////////////////////////////////////////
    //                         tokenURI TESTS
    // //////////////////////////////////////////////////////////////*/

    function test_tokenURINonExistentToken(uint256 _tokenID) public {
        vm.startPrank(minter1);
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.NonExistentToken.selector));
        playPopGo.tokenURI(_tokenID);
    }

    function test_tokenURIUnrevealed() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);

        vm.startPrank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.2 ether}(2);

        string memory tokenURI1 = playPopGo.tokenURI(1);
        string memory tokenURI2 = playPopGo.tokenURI(2);
        assertEq(tokenURI1, unrevealedURI);
        assertEq(tokenURI2, unrevealedURI);
        vm.stopPrank();
    }

    function test_tokenURIRevealed() public {
        // Start off by requesting random offset
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.OPEN);
        uint256 requestId = playPopGo.startReveal();
        vm.stopPrank();
        // Create a uint256 array and push 100
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 9998;
        vrfCoordinator.fulfillRandomWords(requestId, address(playPopGo), randomWords);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.2 ether}(2);

        string memory tokenURI1 = playPopGo.tokenURI(1);
        assertEq(tokenURI1, "https://baseURI/9999");
        string memory tokenURI2 = playPopGo.tokenURI(2);
        assertEq(tokenURI2, "https://baseURI/0");
    }
}

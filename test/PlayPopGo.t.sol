// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PlayPopGo} from "../src/PlayPopGo.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import {MerkleTree} from "./utils/MerkleTree/MerkleTree.sol";
import {VRFCoordinatorV2Mock} from "./utils/mocks/VRFCoordinatorV2Mock.sol";
import {LinkTokenMock} from "./utils/mocks/LinkTokenMock.sol";
import {DreamboxMock} from "../test/utils/mocks/DreamboxMock.sol";

contract PlayPopGoTest is Test {
    DreamboxMock dreambox;
    PlayPopGo playPopGo;
    VRFCoordinatorV2Mock vrfCoordinator;
    LinkTokenMock linkToken;

    address owner;
    address minter1;
    address minter2;
    address minter3;
    address withdrawAddress;

    // ---------- CONSTRUCTOR ARGS ----------
    string public postRevealURI = "https://postRevealURI/";
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
        dreambox = new DreamboxMock("uri");
        withdrawAddress = makeAddr("withdrawAddress");
        owner = makeAddr("owner");
        minter1 = makeAddr("minter1");
        minter2 = makeAddr("minter2");
        minter3 = makeAddr("minter3");
        vm.deal(owner, 100 ether);
        vm.deal(minter1, 100 ether);
        vm.deal(minter2, 100 ether);
        vm.deal(minter3, 100 ether);

        vm.startPrank(owner);
        linkToken = new LinkTokenMock();
        vrfCoordinator = new VRFCoordinatorV2Mock(10 * 3, 10 * 3);
        playPopGo = new PlayPopGo(
            address(dreambox),
            withdrawAddress,
            unrevealedURI,
            postRevealURI,
            maxSupply,
            mintCost,
            address(vrfCoordinator),
            vrfSubscriptionId,
            vrfGasLane,
            vrfCallbackGasLimit
        );

        dreambox.mint(minter1, minter2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            setters TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setBaseUri(string memory _uri) public {
        vm.prank(owner);
        playPopGo.setPostRevealURI(_uri);
        assertEq(playPopGo._postRevealURI(), _uri);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setPostRevealURI(_uri);
    }

    function test_setMaxSupply(uint256 _maxSupply) public {
        vm.startPrank(owner);
        playPopGo.setMaxSupply(_maxSupply);
        assertEq(playPopGo._maxSupply(), _maxSupply);

        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
        vm.expectRevert(PlayPopGo.SaleIsClosed.selector);
        playPopGo.setMaxSupply(_maxSupply);
        vm.stopPrank();

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setMaxSupply(_maxSupply);
    }

    function test_setSaleStatus() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
        uint256 closedSale = uint256(PlayPopGo.SaleStatus.CLOSED);
        uint256 saleStatus = uint256(playPopGo._saleStatus());
        assertEq(saleStatus, closedSale);

        vm.expectRevert(PlayPopGo.SaleIsClosed.selector);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);
        vm.stopPrank();

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
    }

    function test_setPreRevealURI(string memory _preRevealURI) public {
        vm.prank(owner);
        playPopGo.setPreRevealURI(_preRevealURI);
        assertEq(playPopGo._preRevealURI(), _preRevealURI);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.setPreRevealURI(_preRevealURI);
    }

    function test_withdrawFunds() public {
        assertEq(withdrawAddress.balance, 0 ether);
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();

        vm.prank(owner);
        playPopGo.withdrawFunds();
        assertEq(withdrawAddress.balance, 0.1 ether);

        vm.prank(minter1);
        vm.expectRevert("Ownable: caller is not the owner");
        playPopGo.withdrawFunds();
    }

    /*//////////////////////////////////////////////////////////////
                            startReveal TESTS
    //////////////////////////////////////////////////////////////*/

    function test_startReveal() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();

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
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();
        assertEq(playPopGo.balanceOf(minter1), 1);
        assertEq(playPopGo.ownerOf(1), minter1);
        assertEq(playPopGo._totalMinted(), 1);

        vm.startPrank(minter2, address(minter2));
        playPopGo.publicMint{value: 1 ether}();
        assertEq(playPopGo.balanceOf(minter2), 1);
        assertEq(playPopGo.ownerOf(2), minter2);
        assertEq(playPopGo._totalMinted(), 2);
    }

    function test_publicMintSaleIsNotOpen() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PAUSED);
        vm.prank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.publicMint{value: 0.1 ether}();

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.publicMint{value: 0.1 ether}();

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);
        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.publicMint{value: 0.1 ether}();
    }

    function test_publicMintMaxSupplyReached() public {
        vm.startPrank(owner);
        playPopGo.setMaxSupply(2);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);
        vm.stopPrank();
        vm.prank(minter3, address(minter3));
        playPopGo.publicMint{value: 0.1 ether}();
        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();
        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.MaxSupplyReached.selector);
        playPopGo.publicMint{value: 0.1 ether}();
    }

    function test_publicMintInsufficientFunds() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);
        vm.startPrank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.InsufficientFunds.selector);
        playPopGo.publicMint();
    }

    function test_publicMintAlreadyMinted() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);
        vm.startPrank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.AlreadyMinted.selector));
        playPopGo.publicMint{value: 0.1 ether}();
    }

    /*//////////////////////////////////////////////////////////////
                            dreamboxMint TESTS
    //////////////////////////////////////////////////////////////*/

    function test_dreamboxMint() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        vm.stopPrank();

        vm.prank(minter1, address(minter1));
        playPopGo.dreamboxMint();
        assertEq(playPopGo.balanceOf(minter1), 1);

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);

        vm.prank(minter2, address(minter2));
        playPopGo.dreamboxMint();
        assertEq(playPopGo.balanceOf(minter2), 1);
    }

    function test_dreamboxMintSaleIsNotOpen() public {
        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PAUSED);

        vm.prank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.dreamboxMint();

        vm.prank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.CLOSED);

        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.SaleIsNotOpen.selector);
        playPopGo.dreamboxMint();
    }

    function test_dreamboxMintDreamboxMintUsed() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        vm.stopPrank();

        vm.startPrank(minter1, address(minter1));
        playPopGo.dreamboxMint();
        assertEq(playPopGo.balanceOf(minter1), 1);

        vm.expectRevert(PlayPopGo.AlreadyMinted.selector);
        playPopGo.dreamboxMint();
    }

    function test_dreamboxMintMaxSupplyReached() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        playPopGo.setMaxSupply(1);
        vm.stopPrank();

        vm.prank(minter1, address(minter1));
        playPopGo.dreamboxMint();

        vm.prank(minter2, address(minter2));
        vm.expectRevert(PlayPopGo.MaxSupplyReached.selector);
        playPopGo.dreamboxMint();
    }

    function test_dreamboxMintDreamboxNotSet() public {
        vm.startPrank(owner);
        playPopGo.setDreambox(address(0));
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        vm.stopPrank();

        vm.prank(minter1, address(minter1));
        vm.expectRevert(PlayPopGo.DreamboxNotSet.selector);
        playPopGo.dreamboxMint();
    }

    function test_dreamboxMintNotDreamboxHolder() public {
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.DREAMBOX);
        vm.stopPrank();

        vm.prank(minter3, address(minter3));
        vm.expectRevert(abi.encodeWithSelector(PlayPopGo.NotDreamboxHolder.selector));
        playPopGo.dreamboxMint();
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
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();
        vm.prank(minter2, address(minter2));
        playPopGo.publicMint{value: 0.1 ether}();

        string memory tokenURI1 = playPopGo.tokenURI(1);
        string memory tokenURI2 = playPopGo.tokenURI(2);
        assertEq(tokenURI1, unrevealedURI);
        assertEq(tokenURI2, unrevealedURI);
    }

    function test_tokenURIRevealed() public {
        // Start off by requesting random offset
        vm.startPrank(owner);
        playPopGo.setSaleStatus(PlayPopGo.SaleStatus.PUBLIC);
        uint256 requestId = playPopGo.startReveal();
        vm.stopPrank();
        // Create a uint256 array and push 100
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 9998;
        vrfCoordinator.fulfillRandomWords(requestId, address(playPopGo), randomWords);

        vm.prank(minter1, address(minter1));
        playPopGo.publicMint{value: 0.1 ether}();
        vm.prank(minter2, address(minter2));
        playPopGo.publicMint{value: 0.1 ether}();

        string memory tokenURI1 = playPopGo.tokenURI(1);
        assertEq(tokenURI1, "https://postRevealURI/9999");
        string memory tokenURI2 = playPopGo.tokenURI(2);
        assertEq(tokenURI2, "https://postRevealURI/0");
    }
}

pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PlayPopGo} from "../src/PlayPopGo.sol";

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
    address public vrfCoordinatorV2 = address(0x9);
    uint64 vrfSubscriptionId = 5;
    bytes32 vrfGaLane = bytes32("gaslane");
    uint32 vrfCallbackGasLimit = 1000000;

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
        playPopGo.mint{value: 0.1 ether}(1);
        string memory tokenURI = playPopGo.tokenURI(1);
        assertEq(tokenURI, "https://baseURI/1.json");

        vm.stopPrank();
    }
}

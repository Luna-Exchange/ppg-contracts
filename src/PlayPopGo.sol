// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin/utils/Strings.sol";
import "chainlink-contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "chainlink-contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract PlayPopGo is ERC721Enumerable, Ownable, VRFConsumerBaseV2 {
    // STRUCTS

    struct Metadata {
        uint256 startIndex;
        uint256 endIndex;
        uint256 entropy;
    }

    // IPFS JSON HASH
    // TODO: Update this
    string public constant IPFS_JSON_HASH = "HASH";

    // VRF CONSTANTS & IMMUTABLE
    uint16 private constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 private constant VRF_NUM_WORDS = 1;

    // VRF SETUP
    VRFCoordinatorV2Interface private immutable VRF_COORDINATOR_V2;
    uint64 private immutable VRF_SUBSCRIPTION_ID;
    bytes32 private immutable VRF_GA_LANE;
    uint32 private immutable VRF_CALLBACK_GA_LIMIT;

    // IMMUTABLE STORAGE
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MINT_COST;

    // MUTABLE STORAGE
    uint256 public _offset;
    bool public _offsetRequested;
    string public _uri;

    // EVENTS

    event BatchRevealRequested(uint256 requestId);
    event BatchRevealFinished(uint256 startIndex, uint256 endIndex);
    event OffsetRequested(uint256 requestId);
    event OffsetRequestFulfilled(uint256 offset);

    // ERRORS

    error InvalidAmount();
    error MaxSupplyReached();
    error InsufficientFunds();
    error RevealCriteriaNotMet();
    error RevealInProgress();
    error InsufficientLINK();
    error WithdrawProceedsFailed();
    error NonExistentToken();
    error OffsetAlreadyRequested();

    constructor(
        string memory baseURI,
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint256 mintCost,
        address vrfCoordinatorV2,
        uint64 vrfSubscriptionId,
        bytes32 vrfGasLane,
        uint32 vrfCallbackGasLimit
    ) ERC721(name, symbol) VRFConsumerBaseV2(vrfCoordinatorV2) {
        _setBaseURI(baseURI);
        MAX_SUPPLY = maxSupply;
        MINT_COST = mintCost;
        VRF_COORDINATOR_V2 = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        VRF_SUBSCRIPTION_ID = vrfSubscriptionId;
        VRF_GA_LANE = vrfGasLane;
        VRF_CALLBACK_GA_LIMIT = vrfCallbackGasLimit;
    }

    function mint(uint256 _amount) external payable {
        uint256 totalSupply = totalSupply();
        if (_amount == 0) revert InvalidAmount();
        if (totalSupply + _amount > MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value < MINT_COST * _amount) revert InsufficientFunds();
        for (uint256 i = 1; i <= _amount; i++)
            _safeMint(msg.sender, totalSupply + i);
    }

    function withdrawProceeds() external onlyOwner {
        (bool sent, ) = payable(owner()).call{value: address(this).balance}("");
        if (!sent) revert WithdrawProceedsFailed();
    }

    // SETTERS

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonExistentToken();
        string memory base = _baseURI();
        string memory id = Strings.toString(tokenId);
        string memory json = ".json";
        return string(abi.encodePacked(base, id, json));
    }

    // ERC721 Metadata
    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    function _setBaseURI(string memory baseURI) internal {
        _uri = baseURI;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // This function initiates a batch reveal of pending metadata if the reveal criteria are met.
    function revealPendingMetadata() public returns (uint256 requestId) {
        if (_offsetRequested) revert OffsetAlreadyRequested();

        requestId = VRF_COORDINATOR_V2.requestRandomWords(
            VRF_GA_LANE,
            VRF_SUBSCRIPTION_ID,
            VRF_REQUEST_CONFIRMATIONS,
            VRF_CALLBACK_GA_LIMIT,
            VRF_NUM_WORDS
        );
        _offsetRequested = true;
        emit OffsetRequested(requestId);
    }

    // VRF

    function fulfillRandomWords(
        uint256,
        uint256[] memory randomWords
    ) internal override {
        _offset = randomWords[0];
        emit OffsetRequestFulfilled(_offset);
    }
}

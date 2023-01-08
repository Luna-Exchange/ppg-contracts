// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import "chainlink/v0.8/VRFConsumerBaseV2.sol";
import "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "solmate/utils/MerkleProofLib.sol";
import "solmate/utils/LibString.sol";

contract PlayPopGo is ERC721Enumerable, Ownable, VRFConsumerBaseV2 {
    using LibString for uint256;
    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_MINT_PER_ADDRESS = 5;
    string public constant IPFS_JSON_HASH = "HASH"; // IPFS JSON HASH TODO: Update this

    // CHAINLINK VRF
    uint16 private constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 private constant VRF_NUM_WORDS = 1;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    // CHAINLINK VRF
    VRFCoordinatorV2Interface private immutable VRF_COORDINATOR_V2;
    uint64 private immutable VRF_SUBSCRIPTION_ID;
    bytes32 private immutable VRF_GA_LANE;
    uint32 private immutable VRF_CALLBACK_GA_LIMIT;

    // TOKEN STORAGE
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MINT_COST;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public _offset;
    bool public _offsetRequested;
    string public _uri;
    bytes32 public _root;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchRevealRequested(uint256 requestId);
    event BatchRevealFinished(uint256 startIndex, uint256 endIndex);
    event OffsetRequested(uint256 requestId);
    event OffsetRequestFulfilled(uint256 offset);
    event RootUpdated(bytes32 root);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAmount();
    error MaxSupplyReached();
    error InsufficientFunds();
    error RevealCriteriaNotMet();
    error RevealInProgress();
    error InsufficientLINK();
    error WithdrawProceedsFailed();
    error NonExistentToken();
    error OffsetAlreadyRequested();
    error InvalidMerkleProof(address receiver, bytes32[] proof);
    error MaxMintPerAddressSurpassed(uint256 amount, uint256 maxMintPerAddress);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdrawProceeds() external onlyOwner {
        (bool sent, ) = payable(owner()).call{value: address(this).balance}("");
        if (!sent) revert WithdrawProceedsFailed();
    }

    function setDreamBoxRoot(bytes32 root) external onlyOwner {
        _root = root;
        emit RootUpdated(root);
    }

    function privateMint(bytes32[] calldata proof) external {
        address receiver = msg.sender;
        uint256 tokenId = totalSupply() + 1;

        if (!_verify(_leaf(receiver), proof)) revert InvalidMerkleProof(receiver, proof);

        if (tokenId > MAX_SUPPLY) revert MaxSupplyReached();
        _safeMint(receiver, tokenId);
    }

    function publicMint(uint256 amount) external payable {
        uint256 totalSupply = totalSupply();

        if (amount == 0) revert InvalidAmount();
        if (totalSupply + amount > MAX_SUPPLY) revert MaxSupplyReached();
        if (amount > MAX_MINT_PER_ADDRESS) revert MaxMintPerAddressSurpassed(amount, MAX_MINT_PER_ADDRESS);
        if (msg.value < MINT_COST * amount) revert InsufficientFunds();

        for (uint256 i = 1; i <= amount; i++) _safeMint(msg.sender, totalSupply + i);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonExistentToken();
        string memory base = _baseURI();
        string memory id = Strings.toString(tokenId);
        string memory json = ".json";
        return string(abi.encodePacked(base, id, json));
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function requestRandomOffset() public onlyOwner returns (uint256 requestId) {
        // Function is only callable once
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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _setBaseURI(string memory baseURI) internal {
        _uri = baseURI;
    }

    function _leaf(address receiver) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(receiver));
    }

    function _verify(bytes32 leaf, bytes32[] calldata proof) internal view returns (bool) {
        return MerkleProofLib.verify(proof, _root, leaf);
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        _offset = randomWords[0];
        emit OffsetRequestFulfilled(_offset);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "chainlink/v0.8/VRFConsumerBaseV2.sol";
import "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "solmate/utils/MerkleProofLib.sol";
import "solmate/utils/LibString.sol";

contract PlayPopGo is ERC721, Ownable, VRFConsumerBaseV2 {
    enum SaleStatus {
        PAUSED,
        DREAMBOX,
        OPEN,
        CLOSED
    }

    using LibString for uint256;
    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_MINT_PER_ADDRESS = 2;

    // CHAINLINK VRF
    uint16 private constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 private constant VRF_NUM_WORDS = 1;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    // CHAINLINK VRF
    VRFCoordinatorV2Interface private immutable VRF_COORDINATOR_V2;
    uint64 private immutable VRF_SUBSCRIPTION_ID;
    bytes32 private immutable VRF_GAS_LANE;
    uint32 private immutable VRF_CALLBACK_GA_LIMIT;

    // TOKEN STORAGE
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MINT_COST;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    SaleStatus public _saleStatus;

    // REVEAL
    uint256 public _offset;
    bool public _revealed;
    string public _uri;
    string public _prerevealURI;

    uint256 public _mintCount;
    address public _withdrawAddress;
    bytes32 public _root;

    mapping(address => uint256) _addressMintCount;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Revealed(uint256 requestId);
    event OffsetRequestFulfilled(uint256 offset);
    event RootUpdated(bytes32 root);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error SaleIsNotOpen();
    error SaleIsClosed();
    error InvalidAmount();
    error MaxSupplyReached();
    error InsufficientFunds();
    error WithdrawProceedsFailed();
    error NonExistentToken();
    error AlreadyRevealed();
    error InvalidMerkleProof(address receiver, bytes32[] proof);
    error MaxMintPerAddressSurpassed(uint256 amount, uint256 maxMintPerAddress);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier callerIsReceiver() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address withdrawAddress,
        string memory baseURI,
        string memory prerevealURI,
        uint256 maxSupply,
        uint256 mintCost,
        address vrfCoordinatorV2,
        uint64 vrfSubscriptionId,
        bytes32 vrfGasLane,
        uint32 vrfCallbackGasLimit
    ) ERC721("PlayPopGo", "PPG") VRFConsumerBaseV2(vrfCoordinatorV2) {
        _withdrawAddress = withdrawAddress;
        _uri = baseURI;
        _prerevealURI = prerevealURI;
        _saleStatus = SaleStatus.PAUSED;
        MAX_SUPPLY = maxSupply;
        MINT_COST = mintCost;
        VRF_COORDINATOR_V2 = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        VRF_SUBSCRIPTION_ID = vrfSubscriptionId;
        VRF_GAS_LANE = vrfGasLane;
        VRF_CALLBACK_GA_LIMIT = vrfCallbackGasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    function setPreRevealURI(string memory prerevealURI) external onlyOwner {
        _prerevealURI = prerevealURI;
    }

    function setSaleStatus(SaleStatus status) external onlyOwner {
        if (_saleStatus == SaleStatus.CLOSED) revert SaleIsClosed();
        _saleStatus = status;
    }

    function setDreamBoxRoot(bytes32 root) external onlyOwner {
        _root = root;
        emit RootUpdated(root);
    }

    function withdrawFunds() external onlyOwner {
        payable(_withdrawAddress).transfer(address(this).balance);
    }

    function startReveal() external onlyOwner returns (uint256 requestId) {
        // Function is only callable once
        if (_revealed) revert AlreadyRevealed();

        requestId = VRF_COORDINATOR_V2.requestRandomWords(
            VRF_GAS_LANE,
            VRF_SUBSCRIPTION_ID,
            VRF_REQUEST_CONFIRMATIONS,
            VRF_CALLBACK_GA_LIMIT,
            VRF_NUM_WORDS
        );
        _revealed = true;
        emit Revealed(requestId);
    }

    function dreamboxMint(bytes32[] calldata proof) external callerIsReceiver {
        uint256 tokenId = _mintCount + 1;
        address receiver = msg.sender;

        if (_saleStatus != SaleStatus.OPEN && _saleStatus != SaleStatus.DREAMBOX) revert SaleIsNotOpen();
        if (_addressMintCount[receiver] > MAX_MINT_PER_ADDRESS)
            revert MaxMintPerAddressSurpassed(_addressMintCount[receiver], MAX_MINT_PER_ADDRESS);
        if (tokenId > MAX_SUPPLY) revert MaxSupplyReached();

        if (!_verify(_leaf(receiver), proof)) revert InvalidMerkleProof(receiver, proof);

        ++_mintCount;
        ++_addressMintCount[receiver];
        _mint(receiver, tokenId);
    }

    function publicMint(uint256 amount) external payable callerIsReceiver {
        if (_saleStatus != SaleStatus.OPEN) revert SaleIsNotOpen();
        if (amount == 0) revert InvalidAmount();
        if (_mintCount + amount > MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value < MINT_COST * amount) revert InsufficientFunds();

        uint256 addressMintCount = _addressMintCount[msg.sender];

        for (uint256 i = 1; i <= amount; i++) {
            if (addressMintCount >= MAX_MINT_PER_ADDRESS)
                revert MaxMintPerAddressSurpassed(addressMintCount, MAX_MINT_PER_ADDRESS);
            ++_mintCount;
            ++addressMintCount;
            _mint(msg.sender, _mintCount);
        }
        _addressMintCount[msg.sender] = addressMintCount;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonExistentToken();

        // If metadata is unrevealed, return the unrevealed URI
        if (!_revealed) return _prerevealURI;

        string memory id = LibString.toString(((tokenId + _offset) % MAX_SUPPLY));
        return string(abi.encodePacked(_uri, id));
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _leaf(address receiver) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(receiver));
    }

    function _verify(bytes32 leaf, bytes32[] calldata proof) internal view returns (bool) {
        return MerkleProofLib.verify(proof, _root, leaf);
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        _offset = randomWords[0] % MAX_SUPPLY;
        _revealed = true;
        emit OffsetRequestFulfilled(_offset);
    }
}

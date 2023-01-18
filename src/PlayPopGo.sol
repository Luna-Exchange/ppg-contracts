// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "chainlink/v0.8/VRFConsumerBaseV2.sol";
import "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "solmate/utils/MerkleProofLib.sol";
import "solmate/utils/LibString.sol";

/// @title PlayPopGo NFT Contract
/// @author Clique
contract PlayPopGo is ERC721, Ownable, VRFConsumerBaseV2 {
    enum SaleStatus {
        PAUSED, // No one can mint
        DREAMBOX, // Only dreambox holders can mint
        OPEN, // Anyone can mint
        CLOSED // No one can mint and certain functinos are disabled
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
    uint256 public immutable MINT_COST;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    SaleStatus public _saleStatus;

    uint256 public _maxSupply;
    uint256 public _mintCount;
    address public _withdrawAddress;
    bytes32 public _dreamBoxRoot;

    // REVEAL
    uint256 public _offset;
    bool public _revealed;
    string public _uri;
    string public _preRevealURI;

    mapping(address => uint256) _addressMintCount;
    mapping(address => bool) _dreamboxMinted;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Revealed(uint256 requestId);
    event OffsetRequestFulfilled(uint256 offset);
    event DreamboxRootUpdated(bytes32 dreamBoxRoot);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event SaleStatusUpdated(SaleStatus newSaleStatus);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error SaleIsNotOpen();
    error SaleIsClosed();
    error InvalidAmount();
    error MaxSupplyReached();
    error InsufficientFunds();
    error NonExistentToken();
    error AlreadyRevealed();
    error DreamboxMintUsed();
    error InvalidMerkleProof(address receiver, bytes32[] proof);
    error MaxMintPerAddressSurpassed(uint256 amount, uint256 maxMintPerAddress);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Modifier checks that the caller is not a smart contract
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
        string memory preRevealURI,
        uint256 maxSupply,
        uint256 mintCost,
        address vrfCoordinatorV2,
        uint64 vrfSubscriptionId,
        bytes32 vrfGasLane,
        uint32 vrfCallbackGasLimit
    ) ERC721("PlayPopGo", "PPG") VRFConsumerBaseV2(vrfCoordinatorV2) {
        _withdrawAddress = withdrawAddress;
        _uri = baseURI;
        _preRevealURI = preRevealURI;
        _saleStatus = SaleStatus.PAUSED;
        _maxSupply = maxSupply;
        MINT_COST = mintCost;
        VRF_COORDINATOR_V2 = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        VRF_SUBSCRIPTION_ID = vrfSubscriptionId;
        VRF_GAS_LANE = vrfGasLane;
        VRF_CALLBACK_GA_LIMIT = vrfCallbackGasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the contract's baseURI
    /// @dev Only callable by the contract owner
    /// @param baseURI The new baseURI
    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    /// @notice Sets the contract's pre-reveal URI
    /// @dev Only callable by the contract owner
    /// @param preRevealURI The new pre-reveal URI
    function setPreRevealURI(string memory preRevealURI) external onlyOwner {
        _preRevealURI = preRevealURI;
    }

    /// @notice Sets the contract's maximum supply
    /// @dev Only callable by the contract owner
    /// @dev Reverts if the sale is closed
    /// @param maxSupply The new maximum supply
    function setMaxSupply(uint256 maxSupply) external onlyOwner {
        if (_saleStatus == SaleStatus.CLOSED) revert SaleIsClosed();
        _maxSupply = maxSupply;
        emit MaxSupplyUpdated(maxSupply);
    }

    /// @notice Sets the contract's sale status
    /// @dev Only callable by the contract owner
    /// @dev Reverts if the sale is closed
    /// @param status The new sale status
    function setSaleStatus(SaleStatus status) external onlyOwner {
        if (_saleStatus == SaleStatus.CLOSED) revert SaleIsClosed();
        _saleStatus = status;
        emit SaleStatusUpdated(status);
    }

    /// @notice Sets the contract's dreambox root for dreambox minting
    /// @dev Only callable by the contract owner
    /// @param dreamBoxRoot The new dreambox root
    function setDreamboxRoot(bytes32 dreamBoxRoot) external onlyOwner {
        _dreamBoxRoot = dreamBoxRoot;
        emit DreamboxRootUpdated(dreamBoxRoot);
    }

    /// @notice Withdraws the contract's funds
    /// @dev Only callable by the contract owner
    function withdrawFunds() external onlyOwner {
        payable(_withdrawAddress).transfer(address(this).balance);
    }

    /// @notice Initializes the contract's reveal process
    /// @dev Only callable by the contract owner
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

    /// @notice Mints a token for the caller
    /// @param amount The amount of tokens to mint
    function publicMint(uint256 amount) external payable callerIsReceiver {
        if (_saleStatus != SaleStatus.OPEN) revert SaleIsNotOpen();
        if (amount == 0) revert InvalidAmount();
        if (_mintCount + amount > _maxSupply) revert MaxSupplyReached();
        if (msg.value < MINT_COST * amount) revert InsufficientFunds();
        if (_addressMintCount[msg.sender] + amount > MAX_MINT_PER_ADDRESS)
            revert MaxMintPerAddressSurpassed(_addressMintCount[msg.sender], MAX_MINT_PER_ADDRESS);

        _addressMintCount[msg.sender] += amount; // Update address mint count

        for (uint256 i = 1; i <= amount; i++) {
            ++_mintCount; // Update total mint count
            _mint(msg.sender, _mintCount); // Mint token
        }
    }

    /// @notice Mints a token for a caller who holds a deambox
    /// @param proof The merkle proof for the caller's address
    function dreamboxMint(bytes32[] calldata proof) external callerIsReceiver {
        uint256 tokenId = _mintCount + 1;
        address receiver = msg.sender;

        if (_saleStatus != SaleStatus.OPEN && _saleStatus != SaleStatus.DREAMBOX) revert SaleIsNotOpen();
        if (_dreamboxMinted[receiver] == true) revert DreamboxMintUsed();
        if (tokenId > _maxSupply) revert MaxSupplyReached();

        if (!_verify(_leaf(receiver), proof)) revert InvalidMerkleProof(receiver, proof);

        _dreamboxMinted[receiver] = true;
        ++_mintCount;
        ++_addressMintCount[receiver];
        _mint(receiver, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a token's URI
    /// @notice If the metadata is unrevealed, returns the pre-reveal URI
    /// @param tokenId The token's ID
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonExistentToken();

        // If metadata is unrevealed, return the unrevealed URI
        if (!_revealed) return _preRevealURI;

        string memory id = LibString.toString(((tokenId + _offset) % _maxSupply));
        return string(abi.encodePacked(_uri, id));
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Consturcts a leaf from a given address
    function _leaf(address receiver) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(receiver));
    }

    /// @notice Verifies a merkle proof
    /// @param leaf The leaf to verify
    /// @param proof The merkle proof
    function _verify(bytes32 leaf, bytes32[] calldata proof) internal view returns (bool) {
        return MerkleProofLib.verify(proof, _dreamBoxRoot, leaf);
    }

    /// @notice Fulfills a random number request
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        _offset = randomWords[0] % _maxSupply;
        _revealed = true;
        emit OffsetRequestFulfilled(_offset);
    }
}

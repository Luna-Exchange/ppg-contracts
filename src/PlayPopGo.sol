// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "chainlink/v0.8/VRFConsumerBaseV2.sol";
import "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "solmate/utils/LibString.sol";
import "solmate/utils/MerkleProofLib.sol";

/// @title PlayPopGo NFT Contract
/// @author Clique
contract PlayPopGo is ERC721, Ownable, VRFConsumerBaseV2 {
    enum SaleStatus {
        PAUSED, // No one can mint
        DREAMBOX, // Only dreambox holders can mint
        PUBLIC, // Anyone can mint
        CLOSED // No one can mint and certain functions are disabled
    }

    using LibString for uint256;
    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

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
    uint256 public _totalMinted;
    address public _withdrawAddress;
    bytes32 public _dreamboxRoot;

    // REVEAL
    uint256 public _offset;
    bool public _revealed;
    string public _postRevealURI;
    string public _preRevealURI;

    mapping(address => bool) _minters;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Revealed(uint256 requestId);
    event OffsetRequestFulfilled(uint256 offset);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event SaleStatusUpdated(SaleStatus newSaleStatus);
    event DreamboxRootUpdated(bytes32 dreamboxRoot);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error SaleIsNotPublic();
    error SaleIsClosed();
    error InvalidAmount();
    error MaxSupplyReached();
    error InsufficientFunds();
    error NonExistentToken();
    error AlreadyRevealed();
    error AlreadyMinted();
    error InvalidMerkleProof(address receiver, bytes32[] proof);

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
        string memory preRevealURI,
        string memory postRevealURI,
        uint256 maxSupply,
        uint256 mintCost,
        address vrfCoordinatorV2,
        uint64 vrfSubscriptionId,
        bytes32 vrfGasLane,
        uint32 vrfCallbackGasLimit
    ) ERC721("PlayPopGo", "PPG") VRFConsumerBaseV2(vrfCoordinatorV2) {
        _withdrawAddress = withdrawAddress;
        _preRevealURI = preRevealURI;
        _postRevealURI = postRevealURI;
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

    /// @notice Sets the contract's pre-reveal URI
    /// @dev Only callable by the contract owner
    /// @param preRevealURI The new pre-reveal URI
    function setPreRevealURI(string memory preRevealURI) external onlyOwner {
        _preRevealURI = preRevealURI;
    }

    /// @notice Sets the contract's postRevealURI
    /// @dev Only callable by the contract owner
    /// @param postRevealURI The new postRevealURI
    function setPostRevealURI(string memory postRevealURI) external onlyOwner {
        _postRevealURI = postRevealURI;
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

    /// @notice Sets the contract's dreambox root for dreambox minting
    /// @dev Only callable by the contract owner
    /// @param dreamboxRoot The new dreambox root
    function setDreamboxRoot(bytes32 dreamboxRoot) external onlyOwner {
        _dreamboxRoot = dreamboxRoot;
        emit DreamboxRootUpdated(dreamboxRoot);
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
    function publicMint() external payable callerIsReceiver {
        if (_saleStatus != SaleStatus.PUBLIC) revert SaleIsNotPublic();
        if (_totalMinted >= _maxSupply) revert MaxSupplyReached();
        if (_minters[msg.sender] == true) revert AlreadyMinted();
        if (msg.value < MINT_COST) revert InsufficientFunds();

        _minters[msg.sender] = true;
        _mint(msg.sender, _totalMinted); // Mint token
        ++_totalMinted; // Update total mint count
    }

    /// @notice Mints a token for a caller who holds a deambox
    function dreamboxMint(bytes32[] calldata proof) external callerIsReceiver {
        if (_saleStatus != SaleStatus.PUBLIC && _saleStatus != SaleStatus.DREAMBOX) revert SaleIsNotPublic();
        if (_totalMinted >= _maxSupply) revert MaxSupplyReached();
        if (_minters[msg.sender] == true) revert AlreadyMinted();

        if (!_verify(_leaf(msg.sender), proof)) revert InvalidMerkleProof(msg.sender, proof);

        _minters[msg.sender] = true;
        _mint(msg.sender, _totalMinted);
        ++_totalMinted;
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
        return string.concat(_postRevealURI, id);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fulfills a random number request
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        _offset = randomWords[0] % _maxSupply;
        _revealed = true;
        emit OffsetRequestFulfilled(_offset);
    }

    /// @notice Consturcts a leaf from a given address
    function _leaf(address receiver) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(receiver));
    }

    /// @notice Verifies a merkle proof
    /// @param leaf The leaf to verify
    /// @param proof The merkle proof
    function _verify(bytes32 leaf, bytes32[] calldata proof) internal view returns (bool) {
        return MerkleProofLib.verify(proof, _dreamboxRoot, leaf);
    }
}

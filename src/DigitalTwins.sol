// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";
import "solmate/utils/MerkleProofLib.sol";

error MaxSupplyReached();
error MintIsNotActive();
error AlreadyClaimed();
error OnlyEOA();
error NotEnoughMoneyToBuyNft();

/// @title DigitalTwins Contract
/// @author Insomnia Labs
contract DigitalTwins is ERC1155, Ownable {
    // Emitted when URI is set.
    event SetURI(string uri);

    // Emitted when mintActive is set.
    event SetMintActive(bool mintActive);

    // Emitted when token price is set.
    event SetNftPrice(uint256 nftPrice);
    
    // Emitted when relayer is set.
    event SetRelayer(address relayer);

    // Mapping of account addresses that have already minted a dreambox.
    mapping(address => mapping(uint256 => bool)) public claimed;

    // Counter for the number of tokens minted.
    mapping(uint256 => uint256) public totalMinted;

    // Checks if the mint is active.
    bool mintActive = false;

    // The total supply of tokens will be capped at 3000.
    uint256 constant MAX_SUPPLY = 3333;

    // NFT price
    uint256 public nftPrice;

    // The Relayer address
    address public relayer;

    /**
     * @dev Constructs a new Dreambox contract.
     * @param _uri The URI for the token metadata.
     * @param _relayer The address of the relayer.
     */
    constructor(
        string memory _uri,
        address _relayer
    ) ERC1155(_uri) {
        relayer = _relayer;
    }

    /**
     * @dev Returns the URI for a given token ID.
     * @param tokenId The token ID.
     * @return The URI string.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), tokenId));
    }

    /**
     * @dev Sets the URI for the token metadata.
     * Only the contract owner can call this function.
     * @param _uri The new URI.
     */
    function setURI(string memory _uri) external onlyOwner {
        _setURI(_uri);
        emit SetURI(_uri);
    }

    /**
     * @dev Activates or closes the minting process.
     * Only the contract owner can call this function.
     * @param _mintActive The mintActive status.
     */
    function setMintActive(bool _mintActive) external onlyOwner {
        mintActive = _mintActive;
        emit SetMintActive(_mintActive);
    }

    /**
     * @dev Sets the price of the NFT.
     * Only the contract owner can call this function.
     * @param _nftPrice The new NFT price.
     */
    function setNftPrice(uint256 _nftPrice) external onlyOwner {
        nftPrice = _nftPrice;
        emit SetNftPrice(_nftPrice);
    }

    /**
     * @dev Sets the address of the relayer.
     * Only the contract owner can call this function.
     * @param _relayer The new relayer address.
     */
    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit SetRelayer(_relayer);
    }

    /**
     * @dev Mints NFTs and sends them to the recipient.
     * @param recipient The address of the NFT recipient.
     * @param tokenId The token ID of the NFT.
     * @param amount The amount of NFTs to mint.
     */
    function mint(
        address recipient, 
        uint256 orderId,
        uint256 tokenId,
        uint256 amount
    ) external payable {
        if (!mintActive) revert MintIsNotActive();

        if(msg.sender == relayer) {
            if (claimed[recipient][orderId]) revert AlreadyClaimed();
            claimed[recipient][orderId] = true;
        }
        else 
            if(msg.value != nftPrice * amount) revert NotEnoughMoneyToBuyNft();
        
        totalMinted[tokenId] += amount;

        _mint(recipient, tokenId, amount, "");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";
import "solmate/utils/MerkleProofLib.sol";

error MintIsNotActive();
error AlreadyClaimed();
error InvalidTokenId();
error OnlyOneTokenIdPossible();
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

    // Emitted when fee recipient is set.
    event SetFeeRecipient(address feeRecipient);

    // Mapping of account addresses that have already minted a dreambox.
    mapping(uint256 => bool) public claimed;

    // Checks if the mint is active.
    bool mintActive = false;

    // NFT price
    uint256 public nftPrice;

    // The Relayer address
    address public relayer;

    // The Fee Recipient address
    address payable public feeRecipient;

    /**
     * @dev Constructs a new Dreambox contract.
     * @param _uri The URI for the token metadata.
     * @param _relayer The address of the relayer.
     */
    constructor(
        string memory _uri,
        address _relayer,
        address payable _feeRecipient
    ) ERC1155(_uri) {
        relayer = _relayer;
        feeRecipient = _feeRecipient;
    }

    modifier onlyRelayer {
        require(msg.sender == relayer);
        _;
    }
    /**
     * @dev Returns the URI for a given token ID.
     * @param tokenId The token ID.
     * @return The URI string.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), _toString(tokenId)));
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
     * @dev Sets the address of the fee recipient.
     * Only the contract owner can call this function.
     * @param _feeRecipient The new relayer address.
     */
    function setFeeRecipient(address payable _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
        emit SetFeeRecipient(_feeRecipient);
    }

    /**
     * @dev Mints NFTs and sends them to the recipient.
     * @param recipient The address of the NFT recipient.
     * @param tokenIds The token IDs of the NFT.
     * @param amounts The amounts of NFTs to mint.
     */
    function mintRelayer(
        address recipient, 
        uint256 orderId,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external onlyRelayer {
        if (!mintActive) revert MintIsNotActive();

        if (claimed[orderId]) revert AlreadyClaimed();
        claimed[orderId] = true;

        _mintBatch(recipient, tokenIds, amounts, "");
    }

    /**
     * @dev Mints NFTs and sends them to the recipient.
     * @param recipient The address of the NFT recipient.
     * @param tokenId The token ID of the NFT.
     * @param amount The amount of NFTs to mint.
     */
    function mint(
        address recipient, 
        uint256 tokenId,
        uint256 amount
    ) external payable {
        if (!mintActive) revert MintIsNotActive();

        if(tokenId > 18) revert InvalidTokenId();
        if(msg.value != nftPrice * amount) revert NotEnoughMoneyToBuyNft();

        _mint(recipient, tokenId, amount, "");

        (bool success, ) = feeRecipient.call{value: msg.value}("");
        require(success, "Failed to withdraw");
    }

    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     */
    function _toString(uint256 value) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}

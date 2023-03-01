// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";

/// @title DigitalTwins Contract
/// @author Clique
contract DigitalTwins is ERC1155, Ownable {
    /// @notice Contract constructor
    /// @param uri The URI for the token metadata
    /// @param to The address to mint the tokens to
    /// @param ids The token ids to mint
    /// @param amounts The amounts of tokens to mint
    /// @param data The data to pass to the receiver
    constructor(
        string memory uri,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) ERC1155(uri) {
        _mintBatch(to, ids, amounts, data);
    }

    /// @notice Set the URI for the token metadata
    /// @param newuri The new URI for the token metadata
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /// @notice Mint tokens
    /// @param to The address to mint the tokens to
    /// @param id The token id to mint
    /// @param amount The amount of tokens to mint
    /// @param data The data to pass to the receiver
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(to, id, amount, data);
    }

    /// @notice Mint batch of tokens
    /// @param to The address to mint the tokens to
    /// @param ids The token ids to mint
    /// @param amounts The amounts of tokens to mint
    /// @param data The data to pass to the receiver
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
}

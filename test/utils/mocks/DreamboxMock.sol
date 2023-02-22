// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";
import "solmate/utils/MerkleProofLib.sol";

error MaxSupplyReached();
error MintIsNotActive();
error AlreadyMinted();
error OnlyEOA();
error InvalidMerkleProof(address receiver, bytes32[] proof);

/// @title PlayPopGo Dreambox Contract
/// @author Clique
contract DreamboxMock is ERC1155, Ownable {
    constructor(string memory uri) ERC1155(uri) {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account1, address account2) public {
        _mint(account1, 1, 1, "");
        _mint(account2, 1, 1, "");
    }
}

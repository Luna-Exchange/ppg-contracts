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
contract Dreambox is ERC1155, Ownable {
    // The total supply of tokens will be capped at 3000.
    uint256 constant MAX_SUPPLY = 3000;

    // Checks if the mint is active.
    bool _mintActive = false;

    // Counter for the number of tokens minted.
    uint256 public _totalMinted = 1;

    // The Merkle root of the account addresses that are allowed to mint tokens.
    bytes32 public _root;

    // Mapping of account addresses that have already minted a dreambox.
    mapping(address => bool) public _minters;

    /// @dev Constructs a new Dreambox contract.
    /// @param uri The URI for the token metadata.
    constructor(string memory uri) ERC1155(uri) {}

    /// @dev Sets the URI.
    /// @param newuri The new URI.
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /// @dev Sets the Merkle root.
    /// @param root The new Merkle root.
    function setRoot(bytes32 root) public onlyOwner {
        _root = root;
    }

    /// @dev Activates the mint.
    function activateMint() public onlyOwner {
        _mintActive = true;
    }

    /// @dev Mints a token to the given account.
    /// @param account The account to mint the token to.
    /// @param proof The Merkle proof for the account.
    function mint(address account, bytes32[] calldata proof) public {
        if (!_mintActive) revert MintIsNotActive();
        if (_minters[account]) revert AlreadyMinted();
        if (tx.origin != account) revert OnlyEOA();
        if (_totalMinted >= 3000) revert MaxSupplyReached();

        if (!_verify(_leaf(account), proof)) revert InvalidMerkleProof(account, proof);

        _minters[account] = true;
        ++_totalMinted;

        _mint(account, 1, 1, "");
    }

    /// @dev Constructs a leaf from an account address.
    /// @param account The account address.
    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    /// @dev Verifies a Merkle proof.
    /// @param leaf The leaf to verify.
    /// @param proof The Merkle proof.
    function _verify(bytes32 leaf, bytes32[] calldata proof) internal view returns (bool) {
        return MerkleProofLib.verify(proof, _root, leaf);
    }
}

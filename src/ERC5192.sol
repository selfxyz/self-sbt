// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import { IERC5192 } from "./interfaces/IERC5192.sol";

abstract contract ERC5192 is ERC721, IERC5192 {
    bool private isLocked;

    error ERC5192Locked();

    constructor(string memory _name, string memory _symbol, bool _isLocked) ERC721(_name, _symbol) {
        isLocked = _isLocked;
    }

    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId); // Check if token exists
        return isLocked;
    }

    // Override the internal update function to prevent transfers when locked
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        if (isLocked && _ownerOf(tokenId) != address(0) && to != address(0)) {
            revert ERC5192Locked();
        }
        return super._update(to, tokenId, auth);
    }

    // Override approval functions to prevent approvals when locked
    function approve(address approved, uint256 tokenId) public virtual override {
        if (isLocked) revert ERC5192Locked();
        super.approve(approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (isLocked) revert ERC5192Locked();
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }
}

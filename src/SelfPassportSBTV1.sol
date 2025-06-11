// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SelfVerificationRoot } from "@selfxyz/contracts/contracts/abstract/SelfVerificationRoot.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ERC5192 } from "./ERC5192.sol";

contract SelfPassportSBTV1 is SelfVerificationRoot, ERC5192, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 nullifier => uint256 tokenId) internal _nullifierToTokenId;
    mapping(address user => uint256 tokenId) internal _userToTokenId;
    mapping(uint256 tokenId => uint256 expiryTimestamp) internal _expiryTimestamps;
    uint64 internal _nextTokenId;
    uint256 public validityPeriod;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SBTMinted(address indexed to, uint256 indexed tokenId, uint256 indexed expiryTimestamp);
    event SBTUpdated(uint256 indexed tokenId, uint256 indexed newExpiryTimestamp);
    event SBTBurned(uint256 indexed tokenId, address indexed user);
    event ValidityPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RegisteredNullifier();
    error InvalidValidityPeriod();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _identityVerificationHubAddress,
        uint256 _scopeValue,
        uint256[] memory _attestationIdList,
        address _owner,
        uint256 _validityPeriod
    )
        SelfVerificationRoot(_identityVerificationHubAddress, _scopeValue, _attestationIdList)
        ERC5192("SelfPassportSBTV1", "SELFSBTV1", true) // Lock the token
        Ownable(_owner)
    {
        if (_validityPeriod == 0) revert InvalidValidityPeriod();
        _nextTokenId = 1;
        validityPeriod = _validityPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                             MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function verifySelfProof(ISelfVerificationRoot.DiscloseCircuitProof memory proof) public override {
        uint256 nullifier = proof.pubSignals[NULLIFIER_INDEX];
        address receiver = address(uint160(proof.pubSignals[USER_IDENTIFIER_INDEX]));

        // Check if nullifier has been used
        uint256 nullifierTokenId = _nullifierToTokenId[nullifier];
        bool nullifierIsUsed = nullifierTokenId != 0;

        // Check if receiver has SBT
        uint256 receiverTokenId = _userToTokenId[receiver];
        bool receiverHasSBT = receiverTokenId != 0;

        if (!nullifierIsUsed && !receiverHasSBT) {
            // Case 1: Nullifier NEW + Receiver NO SBT → mint
            super.verifySelfProof(proof);

            uint256 newExpiryTimestamp = block.timestamp + validityPeriod;
            uint64 newTokenId = _nextTokenId++;

            // Mint token and set expiry
            _mint(receiver, newTokenId);
            _expiryTimestamps[newTokenId] = newExpiryTimestamp;

            // Update mappings
            _nullifierToTokenId[nullifier] = newTokenId;
            _userToTokenId[receiver] = newTokenId;

            emit SBTMinted(receiver, newTokenId, newExpiryTimestamp);
        } else if (!nullifierIsUsed && receiverHasSBT) {
            // Case 2: Nullifier NEW + Receiver HAS SBT → update (no owner check needed)
            super.verifySelfProof(proof);

            uint256 newExpiryTimestamp = block.timestamp + validityPeriod;

            // Update existing token's expiry
            _expiryTimestamps[receiverTokenId] = newExpiryTimestamp;

            // Map this new nullifier to the existing token
            _nullifierToTokenId[nullifier] = receiverTokenId;

            emit SBTUpdated(receiverTokenId, newExpiryTimestamp);
        } else if (nullifierIsUsed && !receiverHasSBT) {
            // Case 3: Nullifier USED + Receiver NO SBT → revert
            revert RegisteredNullifier();
        } else {
            // Case 4: Nullifier USED + Receiver HAS SBT → check owner match
            address nullifierOwner = _ownerOf(nullifierTokenId);

            if (nullifierOwner != receiver) {
                // Owner mismatch → revert
                revert RegisteredNullifier();
            }

            // Owner matches → update expiry
            super.verifySelfProof(proof);

            uint256 newExpiryTimestamp = block.timestamp + validityPeriod;
            _expiryTimestamps[receiverTokenId] = newExpiryTimestamp;

            emit SBTUpdated(receiverTokenId, newExpiryTimestamp);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Burn a user's SBT token
    /// @param tokenId The token ID to burn
    function burnSBT(uint256 tokenId) external onlyOwner {
        address tokenOwner = _ownerOf(tokenId);
        require(tokenOwner != address(0), "Token does not exist");

        // Clean up all mappings
        _userToTokenId[tokenOwner] = 0;
        delete _expiryTimestamps[tokenId];

        // Need to find and clean up nullifier mappings
        // This is a limitation - we can't efficiently reverse lookup nullifiers
        // In practice, this might require an additional mapping or event tracking

        _burn(tokenId);
        emit SBTBurned(tokenId, tokenOwner);
    }

    /// @notice Update the validity period for new tokens
    /// @param _newValidityPeriod The new validity period in seconds
    function setValidityPeriod(uint256 _newValidityPeriod) external onlyOwner {
        if (_newValidityPeriod == 0) revert InvalidValidityPeriod();

        uint256 oldPeriod = validityPeriod;
        validityPeriod = _newValidityPeriod;

        emit ValidityPeriodUpdated(oldPeriod, _newValidityPeriod);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if a token is still valid (not expired)
    /// @param tokenId The token ID to check
    /// @return valid True if token exists and hasn't expired
    function isTokenValid(uint256 tokenId) external view returns (bool valid) {
        if (_ownerOf(tokenId) == address(0)) {
            return false; // Token doesn't exist
        }
        return block.timestamp <= _expiryTimestamps[tokenId];
    }

    /// @notice Get token expiry timestamp
    /// @param tokenId The token ID to check
    /// @return expiryTimestamp The expiry timestamp
    function getTokenExpiry(uint256 tokenId) external view returns (uint256 expiryTimestamp) {
        _requireOwned(tokenId);
        return _expiryTimestamps[tokenId];
    }

    /// @notice Check if a nullifier has been used
    /// @param nullifier The nullifier to check
    /// @return used True if nullifier has been used
    function isNullifierUsed(uint256 nullifier) external view returns (bool used) {
        return _nullifierToTokenId[nullifier] != 0;
    }

    /// @notice Get token ID for a user
    /// @param user The user to check
    /// @return tokenId The token ID (0 if user has no token)
    function getTokenIdByAddress(address user) external view returns (uint256 tokenId) {
        return _userToTokenId[user];
    }

    /// @notice Get the current validity period
    /// @return The validity period in seconds
    function getValidityPeriod() external view returns (uint256) {
        return validityPeriod;
    }
}

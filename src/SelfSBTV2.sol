// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SelfVerificationRoot } from "@selfxyz/contracts-v2/contracts/abstract/SelfVerificationRoot.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts-v2/contracts/interfaces/ISelfVerificationRoot.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts-v2/contracts/interfaces/IIdentityVerificationHubV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { ERC5192 } from "./ERC5192.sol";

/// @title SelfSBTV2
/// @author Self Protocol
/// @notice A Soulbound Token (SBT) implementation for identity verification using Self Protocol's verification system
/// @dev This contract extends SelfVerificationRoot for identity verification, ERC5192 for soulbound functionality,
///      and Ownable for administrative controls. Tokens are non-transferable and have expiry timestamps.
contract SelfSBTV2 is SelfVerificationRoot, ERC5192, Ownable {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Maps nullifiers to their corresponding token IDs for verification tracking
    mapping(uint256 nullifier => uint256 tokenId) internal _nullifierToTokenId;

    /// @dev Maps user addresses to their token IDs (one SBT per user)
    mapping(address user => uint256 tokenId) internal _userToTokenId;

    /// @dev Maps token IDs to their expiry timestamps
    mapping(uint256 tokenId => uint256 expiryTimestamp) internal _expiryTimestamps;

    /// @dev Counter for generating unique token IDs
    uint64 internal _nextTokenId;

    /// @notice The validity period in seconds for newly minted tokens
    uint256 public validityPeriod;

    /// @notice The verification configuration ID used for identity verification
    bytes32 public verificationConfigId;

    /// @notice Maximum age of a signature in seconds (10 minutes)
    uint256 public constant MAX_SIGNATURE_AGE = 600;

    /// @notice EIP-712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @notice EIP-712 type hash for VerifyIdentity message
    bytes32 public constant VERIFY_IDENTITY_TYPEHASH = keccak256("VerifyIdentity(address wallet,uint256 timestamp)");

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a new SBT is minted
    /// @param to The address receiving the SBT
    /// @param tokenId The unique identifier of the minted token
    /// @param expiryTimestamp The timestamp when the token expires
    event SBTMinted(address indexed to, uint256 indexed tokenId, uint256 indexed expiryTimestamp);

    /// @notice Emitted when an existing SBT's expiry is updated
    /// @param tokenId The unique identifier of the updated token
    /// @param newExpiryTimestamp The new expiry timestamp
    event SBTUpdated(uint256 indexed tokenId, uint256 indexed newExpiryTimestamp);

    /// @notice Emitted when an SBT is burned by the owner
    /// @param tokenId The unique identifier of the burned token
    /// @param user The address that owned the burned token
    event SBTBurned(uint256 indexed tokenId, address indexed user);

    /// @notice Emitted when the validity period is updated by the owner
    /// @param oldPeriod The previous validity period in seconds
    /// @param newPeriod The new validity period in seconds
    event ValidityPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the specified verification configuration ID does not exist in the hub
    error VerificationConfigDoesNotExist();

    /// @notice Thrown when attempting to use a nullifier that has already been registered
    error RegisteredNullifier();

    /// @notice Thrown when setting an invalid validity period (zero or negative)
    error InvalidValidityPeriod();

    /// @notice Thrown when attempting to operate on a token that does not exist
    error TokenDoesNotExist();

    /// @notice Thrown when the receiver address is invalid (zero address)
    error InvalidReceiver();

    /// @notice Thrown when the signature doesn't match the receiver
    error InvalidSignature();

    /// @notice Thrown when the signature timestamp is too old
    error SignatureExpired();

    /// @notice Thrown when the user context data is malformed
    error InvalidUserData();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Constructs the SelfPassportSBTV2 contract
    /// @param _identityVerificationHubAddress The address of the Self Protocol verification hub
    /// @param _scopeValue The scope value for the endpoint
    /// @param _owner The address that will own this contract and have administrative privileges
    /// @param _validityPeriod The validity period in seconds for newly minted tokens (must be > 0)
    /// @param _verificationConfigId The verification configuration ID to use for identity verification
    /// @dev Initializes the contract with soulbound token functionality (locked = true)
    /// @dev Validates that the verification config exists in the hub before deployment
    constructor(
        address _identityVerificationHubAddress,
        uint256 _scopeValue,
        address _owner,
        uint256 _validityPeriod,
        bytes32 _verificationConfigId
    )
        SelfVerificationRoot(_identityVerificationHubAddress, _scopeValue)
        ERC5192("SelfSBTV2", "SELFSBTV2", true)
        Ownable(_owner)
    {
        IIdentityVerificationHubV2 hub = IIdentityVerificationHubV2(_identityVerificationHubAddress);
        if (!hub.verificationConfigV2Exists(_verificationConfigId)) {
            revert VerificationConfigDoesNotExist();
        }
        verificationConfigId = _verificationConfigId;

        if (_validityPeriod == 0) revert InvalidValidityPeriod();
        validityPeriod = _validityPeriod;

        _nextTokenId = 1;

        // Initialize EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Self SBT Verification")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                             FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the verification configuration ID for this contract
    /// @dev Overrides SelfVerificationRoot to provide a fixed config ID for all verifications
    function getConfigId(bytes32, bytes32, bytes memory) public view override returns (bytes32) {
        return verificationConfigId;
    }

    /// @notice Custom verification hook that can be overridden by implementing contracts
    /// @param genericDiscloseOutput The generic disclose output from the hub
    /// @param userData The user context data containing the EIP-712 signature
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory genericDiscloseOutput,
        bytes memory userData
    )
        internal
        override
    {
        uint256 nullifier = genericDiscloseOutput.nullifier;
        address receiver = address(uint160(genericDiscloseOutput.userIdentifier));

        if (receiver == address(0)) revert InvalidReceiver();

        // Verify EIP-712 signature from userData
        _verifySignature(receiver, userData);

        // Check if nullifier has been used
        uint256 nullifierTokenId = _nullifierToTokenId[nullifier];
        bool nullifierIsUsed = nullifierTokenId != 0;

        // Check if receiver has SBT
        uint256 receiverTokenId = _userToTokenId[receiver];
        bool receiverHasSBT = receiverTokenId != 0;

        if (!nullifierIsUsed && !receiverHasSBT) {
            // Case 1: Nullifier NEW + Receiver NO SBT → mint
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
            uint256 newExpiryTimestamp = block.timestamp + validityPeriod;

            // Update existing token's expiry
            _expiryTimestamps[receiverTokenId] = newExpiryTimestamp;

            // Map this new nullifier to the existing token
            _nullifierToTokenId[nullifier] = receiverTokenId;

            emit SBTUpdated(receiverTokenId, newExpiryTimestamp);
        } else if (nullifierIsUsed && !receiverHasSBT) {
            // Case 3: Nullifier USED + Receiver NO SBT → recover burned token or revert
            address currentOwner = _ownerOf(nullifierTokenId);

            if (currentOwner == address(0)) {
                // Token was burned by admin, recover to new address with same token ID
                uint256 newExpiryTimestamp = block.timestamp + validityPeriod;

                _mint(receiver, nullifierTokenId);
                _expiryTimestamps[nullifierTokenId] = newExpiryTimestamp;
                _userToTokenId[receiver] = nullifierTokenId;

                emit SBTMinted(receiver, nullifierTokenId, newExpiryTimestamp);
            } else {
                // Token still active, user must ask admin to burn first
                revert RegisteredNullifier();
            }
        } else {
            // Case 4: Nullifier USED + Receiver HAS SBT → check owner match
            address nullifierOwner = _ownerOf(nullifierTokenId);

            if (nullifierOwner != receiver) {
                // Owner mismatch → revert
                revert RegisteredNullifier();
            }

            // Owner matches → update expiry
            uint256 newExpiryTimestamp = block.timestamp + validityPeriod;
            _expiryTimestamps[receiverTokenId] = newExpiryTimestamp;

            emit SBTUpdated(receiverTokenId, newExpiryTimestamp);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Burn a user's SBT token (preserves nullifier mapping for recovery)
    /// @param tokenId The token ID to burn
    /// @dev This function can only be called by the owner. Nullifier mapping is preserved for token recovery.
    function burnSBT(uint256 tokenId) external onlyOwner {
        address tokenOwner = _ownerOf(tokenId);
        if (tokenOwner == address(0)) revert TokenDoesNotExist();

        // Clean up user and expiry mappings (nullifier mapping preserved for recovery)
        _userToTokenId[tokenOwner] = 0;
        delete _expiryTimestamps[tokenId];

        _burn(tokenId);
        emit SBTBurned(tokenId, tokenOwner);
    }

    /// @notice Update the validity period for new tokens
    /// @param _newValidityPeriod The new validity period in seconds
    /// @dev This function can only be called by the owner
    function setValidityPeriod(uint256 _newValidityPeriod) external onlyOwner {
        if (_newValidityPeriod == 0) revert InvalidValidityPeriod();

        uint256 oldPeriod = validityPeriod;
        validityPeriod = _newValidityPeriod;

        emit ValidityPeriodUpdated(oldPeriod, _newValidityPeriod);
    }

    /// @notice Update the scope value for the endpoint
    /// @param _newScopeValue The new scope value
    /// @dev This function can only be called by the owner
    function setScope(uint256 _newScopeValue) external onlyOwner {
        _setScope(_newScopeValue);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if a token is still valid (not expired)
    /// @param tokenId The token ID to check
    /// @return valid True if token exists and hasn't expired
    function isTokenValid(uint256 tokenId) external view returns (bool valid) {
        if (_ownerOf(tokenId) == address(0)) return false; // Token doesn't exist
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

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies the EIP-712 signature from userData
    /// @param expectedSigner The address that should have signed the message
    /// @param userData The user context data containing the signature payload
    function _verifySignature(address expectedSigner, bytes memory userData) internal view {
        // The userData should contain: signature (65 bytes) + timestamp (32 bytes)
        // Minimum expected length: 65 (signature) + 32 (timestamp) = 97 bytes
        if (userData.length < 97) revert InvalidUserData();

        // Extract signature (first 65 bytes)
        bytes memory signature = new bytes(65);
        for (uint256 i = 0; i < 65; i++) {
            signature[i] = userData[i];
        }

        // Extract timestamp (next 32 bytes as uint256)
        uint256 signatureTimestamp;
        assembly {
            // userData points to memory location, first 32 bytes is length
            // Skip: 32 (length) + 65 (signature) = 97
            signatureTimestamp := mload(add(userData, 97))
        }

        // Verify timestamp is within MAX_SIGNATURE_AGE
        if (block.timestamp > signatureTimestamp + MAX_SIGNATURE_AGE) {
            revert SignatureExpired();
        }

        // Reconstruct the EIP-712 struct hash
        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, expectedSigner, signatureTimestamp));

        // Create the EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        // Recover signer from signature using OpenZeppelin's ECDSA
        address recoveredSigner = digest.recover(signature);

        // Verify the signature matches the expected signer
        if (recoveredSigner != expectedSigner) {
            revert InvalidSignature();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SelfStructs } from "@selfxyz/contracts-v2/contracts/libraries/SelfStructs.sol";
import { IPoseidonT3 } from "../interfaces/IPoseidonT3.sol";

/// @title SelfUtils
/// @notice Utility functions for Self Protocol verification config formatting and scope calculation
/// @dev Copied from @selfxyz/contracts to avoid adding a git submodule dependency
library SelfUtils {
    struct UnformattedVerificationConfigV2 {
        uint256 olderThan;
        string[] forbiddenCountries;
        bool ofacEnabled;
    }

    /**
     * @dev Packs an array of forbidden countries into chunks suitable for circuit inputs
     * @param forbiddenCountries Array of 3-character country codes
     * @return output Array of 4 uint256 values containing packed country data
     */
    function packForbiddenCountriesList(
        string[] memory forbiddenCountries
    ) internal pure returns (uint256[4] memory output) {
        uint256 MAX_BYTES_IN_FIELD = 31;
        uint256 REQUIRED_CHUNKS = 4;

        bytes memory packedBytes;

        for (uint256 i = 0; i < forbiddenCountries.length; i++) {
            bytes memory countryBytes = bytes(forbiddenCountries[i]);
            require(countryBytes.length == 3, "Invalid country code: must be exactly 3 characters long");
            packedBytes = abi.encodePacked(packedBytes, countryBytes);
        }

        uint256 maxBytes = packedBytes.length;
        uint256 packSize = MAX_BYTES_IN_FIELD;
        uint256 numChunks = (maxBytes + packSize - 1) / packSize;

        for (uint256 i = 0; i < numChunks && i < REQUIRED_CHUNKS; i++) {
            uint256 sum = 0;
            for (uint256 j = 0; j < packSize; j++) {
                uint256 idx = packSize * i + j;
                if (idx < maxBytes) {
                    sum += uint256(uint8(packedBytes[idx])) << (8 * j);
                }
            }
            output[i] = sum;
        }
    }

    /**
     * @dev Formats an unstructured verification configuration into the standardized circuit-compatible format
     * @param config The simplified input configuration
     * @return verificationConfigV2 The formatted configuration ready for the hub
     */
    function formatVerificationConfigV2(
        UnformattedVerificationConfigV2 memory config
    ) internal pure returns (SelfStructs.VerificationConfigV2 memory verificationConfigV2) {
        bool[3] memory ofacArray;
        ofacArray[0] = config.ofacEnabled;
        ofacArray[1] = config.ofacEnabled;
        ofacArray[2] = config.ofacEnabled;

        verificationConfigV2 = SelfStructs.VerificationConfigV2({
            olderThanEnabled: config.olderThan > 0,
            olderThan: config.olderThan,
            forbiddenCountriesEnabled: config.forbiddenCountries.length > 0,
            forbiddenCountriesListPacked: packForbiddenCountriesList(config.forbiddenCountries),
            ofacEnabled: ofacArray
        });
    }

    /// @notice Returns the PoseidonT3 library address for the current chain
    function getPoseidonAddress() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == 42220) return 0xF134707a4C4a3a76b8410fC0294d620A7c341581; // Celo Mainnet
        if (chainId == 11142220) return 0x0a782f7F9f8Aac6E0bacAF3cD4aA292C3275C6f2; // Celo Sepolia
        return address(0);
    }

    /// @notice Calculates scope from contract address and scope seed using Poseidon hashing
    function calculateScope(address contractAddress, string memory scopeSeed) internal view returns (uint256) {
        address poseidon = getPoseidonAddress();
        require(poseidon != address(0), "PoseidonT3 not available on this chain");

        // Hash the contract address: split hex string into 2 chunks (31 + 11 chars)
        string memory addrStr = addressToHexString(contractAddress);
        uint256 chunk1 = stringToBigInt(substring(addrStr, 0, 31));
        uint256 chunk2 = stringToBigInt(substring(addrStr, 31, 42));
        uint256 addressHash = IPoseidonT3(poseidon).hash([chunk1, chunk2]);

        // Hash address hash with scope seed
        uint256 scopeSeedAsUint = stringToBigInt(scopeSeed);
        return IPoseidonT3(poseidon).hash([addressHash, scopeSeedAsUint]);
    }

    /// @notice Convert string to BigInt using ASCII encoding
    function stringToBigInt(string memory str) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length <= 31, "String too long for BigInt conversion");
        uint256 result = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            require(uint8(strBytes[i]) <= 127, "Non-ASCII character detected");
            result = (result << 8) | uint256(uint8(strBytes[i]));
        }
        return result;
    }

    /// @notice Converts an address to its lowercase hex string representation
    function addressToHexString(address addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    /// @notice Extracts a substring from a given string
    function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}

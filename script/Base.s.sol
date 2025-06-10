// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
        if (from != address(0)) {
            broadcaster = from;
        } else {
            uint256 privateKey =
                vm.envOr({ name: "PRIVATE_KEY", defaultValue: uint256(keccak256(abi.encodePacked(TEST_MNEMONIC))) });
            broadcaster = vm.addr(privateKey);
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    /// @dev Extract substring from a string
    /// @param str Source string
    /// @param startIndex Starting index (inclusive)
    /// @param endIndex Ending index (exclusive)
    /// @return Extracted substring
    function _substring(string memory str, uint256 startIndex, uint256 endIndex) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    /// @dev Convert string to uint256 (assumes valid numeric string)
    /// @param numStr Numeric string to convert
    /// @return Converted uint256 value
    function _stringToUint(string memory numStr) public pure returns (uint256) {
        bytes memory strBytes = bytes(numStr);
        uint256 result = 0;

        for (uint256 i = 0; i < strBytes.length; i++) {
            // Skip whitespace
            if (strBytes[i] == 0x20) continue; // space character

            require(strBytes[i] >= 0x30 && strBytes[i] <= 0x39, "Invalid numeric character");
            result = result * 10 + (uint8(strBytes[i]) - 48); // Convert ASCII to number
        }

        return result;
    }
}

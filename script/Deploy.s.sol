// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { SelfPassportSBTV1 } from "../src/SelfPassportSBTV1.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcast returns (SelfPassportSBTV1 sbt) {
        // Parse comma-separated attestation ID list
        string memory attestationIdListStr = vm.envString("ATTESTATION_ID_LIST");
        uint256[] memory attestationIdList = _parseAttestationIds(attestationIdListStr);

        sbt = new SelfPassportSBTV1(
            vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS"),
            vm.envUint("SCOPE_VALUE"),
            attestationIdList,
            vm.envOr("OWNER_ADDRESS", broadcaster), // Default to broadcaster if not specified
            vm.envOr("VALIDITY_PERIOD", uint256(180 days)) // Default to 180 days if not specified
        );
    }

    /// @dev Parse comma-separated string into uint256 array
    /// @param attestationIdsStr Comma-separated string (e.g., "1,2,3")
    /// @return attestationIds Array of uint256 values
    function _parseAttestationIds(string memory attestationIdsStr)
        public
        pure
        returns (uint256[] memory attestationIds)
    {
        bytes memory strBytes = bytes(attestationIdsStr);

        // Count commas to determine array size
        uint256 commaCount = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == 0x2C) {
                // comma character
                commaCount++;
            }
        }

        // Array size is comma count + 1
        attestationIds = new uint256[](commaCount + 1);

        uint256 currentIndex = 0;
        uint256 startIndex = 0;

        for (uint256 i = 0; i <= strBytes.length; i++) {
            // Process when we hit a comma or reach the end
            if (i == strBytes.length || strBytes[i] == 0x2C) {
                // Extract substring and convert to uint256
                string memory numStr = _substring(attestationIdsStr, startIndex, i);
                attestationIds[currentIndex] = _stringToUint(numStr);
                currentIndex++;
                startIndex = i + 1; // Skip the comma
            }
        }
    }
}

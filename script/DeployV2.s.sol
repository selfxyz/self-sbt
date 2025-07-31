// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { SelfSBTV2 } from "../src/SelfSBTV2.sol";
import { BaseScript } from "./Base.s.sol";
import { console } from "forge-std/console.sol";

/// @title DeployV2
/// @notice Deployment script for SelfSBTV2 contract using CREATE2
contract DeployV2 is BaseScript {
    // Custom errors for deployment verification
    error DeploymentFailed();
    error OwnerMismatch();
    error ValidityPeriodMismatch();
    error ConfigIdMismatch();

    /// @notice Predict the CREATE2 address for SelfSBTV2 deployment
    /// @return predictedAddress The predicted contract address
    /// @dev Uses the same parameters and logic as the actual deployment
    function predictAddress() public view returns (address predictedAddress) {
        address identityVerificationHubAddress = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        address owner = vm.envOr("OWNER_ADDRESS", broadcaster);
        uint256 validityPeriod = vm.envOr("VALIDITY_PERIOD", uint256(180 days));
        bytes32 verificationConfigId = vm.envBytes32("VERIFICATION_CONFIG_ID");
        string memory scopeSeed = vm.envString("SCOPE_SEED");

        // Generate deterministic salt from scope seed (same as deployment)
        bytes32 salt = keccak256(abi.encodePacked("SelfSBTV2_", scopeSeed));

        // Create constructor arguments (using placeholder scope value for prediction)
        bytes memory constructorArgs = abi.encode(
            identityVerificationHubAddress,
            uint256(0), // Placeholder scope value - will be calculated later
            owner,
            validityPeriod,
            verificationConfigId
        );

        // Get the creation code (bytecode + constructor args)
        bytes memory creationCode = abi.encodePacked(type(SelfSBTV2).creationCode, constructorArgs);

        // Use Foundry's native CREATE2 address prediction
        predictedAddress = vm.computeCreate2Address(salt, keccak256(creationCode), broadcaster);

        // Output for workflow parsing
        console.log("PREDICTED_ADDRESS:", predictedAddress);
    }
    /// @notice Main deployment function using CREATE2 for deterministic address
    /// @return sbt The deployed SelfSBTV2 contract instance
    /// @dev Requires the following environment variables:
    ///      - IDENTITY_VERIFICATION_HUB_ADDRESS: Address of the Self Protocol verification hub
    ///      - SCOPE_VALUE: The scope value for the endpoint
    ///      - VERIFICATION_CONFIG_ID: The verification configuration ID (bytes32)
    ///      - SCOPE_SEED: The scope seed used for salt generation
    ///      Optional environment variables:
    ///      - OWNER_ADDRESS: Contract owner (defaults to broadcaster)
    ///      - VALIDITY_PERIOD: Token validity period in seconds (defaults to 180 days)

    function run() public broadcast returns (SelfSBTV2 sbt) {
        address identityVerificationHubAddress = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        uint256 scopeValue = vm.envUint("SCOPE_VALUE");
        address owner = vm.envOr("OWNER_ADDRESS", broadcaster); // Default to broadcaster if not specified
        uint256 validityPeriod = vm.envOr("VALIDITY_PERIOD", uint256(180 days)); // Default to 180 days
        bytes32 verificationConfigId = vm.envBytes32("VERIFICATION_CONFIG_ID");
        string memory scopeSeed = vm.envString("SCOPE_SEED");

        // Generate deterministic salt from scope seed
        bytes32 salt = keccak256(abi.encodePacked("SelfSBTV2_", scopeSeed));

        // Deploy the contract using CREATE2
        sbt = new SelfSBTV2{ salt: salt }(
            identityVerificationHubAddress, scopeValue, owner, validityPeriod, verificationConfigId
        );

        // Log deployment information
        console.log("SelfSBTV2 deployed to:", address(sbt));
        console.log("Identity Verification Hub:", identityVerificationHubAddress);
        console.log("Scope Value:", scopeValue);
        console.log("Scope Seed:", scopeSeed);
        console.log("Salt:", vm.toString(salt));
        console.log("Owner:", owner);
        console.log("Validity Period (seconds):", validityPeriod);
        console.log("Verification Config ID:", vm.toString(verificationConfigId));

        // Verify deployment was successful
        if (address(sbt) == address(0)) revert DeploymentFailed();
        if (sbt.owner() != owner) revert OwnerMismatch();
        if (sbt.getValidityPeriod() != validityPeriod) revert ValidityPeriodMismatch();
        if (sbt.verificationConfigId() != verificationConfigId) revert ConfigIdMismatch();

        console.log("Deployment verification completed successfully!");
    }
}

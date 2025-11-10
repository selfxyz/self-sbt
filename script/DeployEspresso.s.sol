// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { EspressoSelfSBT } from "../src/EspressoSBT.sol";
import { BaseScript } from "./Base.s.sol";
import { console } from "forge-std/console.sol";

/// @title DeployEspresso
/// @notice Deployment script for EspressoSelfSBT contract using standard deployment
contract DeployEspresso is BaseScript {
    // Custom errors for deployment verification
    error DeploymentFailed();
    error OwnerMismatch();
    error ValidityPeriodMismatch();
    error ConfigIdMismatch();

    /// @notice Main deployment function using standard deployment
    /// @return sbt The deployed EspressoSelfSBT contract instance
    /// @dev Requires the following environment variables:
    ///      - IDENTITY_VERIFICATION_HUB_ADDRESS: Address of the Self Protocol verification hub
    ///      - VERIFICATION_CONFIG_ID: The verification configuration ID (bytes32)
    ///      Optional environment variables:
    ///      - OWNER_ADDRESS: Contract owner (defaults to broadcaster)
    ///      - VALIDITY_PERIOD: Token validity period in seconds (defaults to 180 days)
    ///      - PLACEHOLDER_SCOPE: Placeholder scope value (defaults to 1)
    function run() public broadcast returns (EspressoSelfSBT sbt) {
        address hubAddress = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        uint256 placeholderScope = vm.envOr("PLACEHOLDER_SCOPE", uint256(1)); // Use placeholder scope
        address owner = vm.envOr("OWNER_ADDRESS", broadcaster); // Default to broadcaster if not specified
        uint256 validityPeriod = vm.envOr("VALIDITY_PERIOD", uint256(180 days)); // Default to 180 days
        bytes32 verificationConfigId = vm.envBytes32("VERIFICATION_CONFIG_ID");

        // Deploy the contract using standard deployment with placeholder scope
        sbt = new EspressoSelfSBT(hubAddress, placeholderScope, owner, validityPeriod, verificationConfigId);

        // Log deployment information
        console.log("EspressoSelfSBT deployed to:", address(sbt));
        console.log("Identity Verification Hub:", hubAddress);
        console.log("Placeholder Scope Value:", placeholderScope);
        console.log("Owner:", owner);
        console.log("Validity Period (seconds):", validityPeriod);
        console.log("Verification Config ID:", vm.toString(verificationConfigId));

        // Verify deployment was successful
        if (address(sbt) == address(0)) revert DeploymentFailed();
        if (sbt.owner() != owner) revert OwnerMismatch();
        if (sbt.getValidityPeriod() != validityPeriod) revert ValidityPeriodMismatch();
        if (sbt.verificationConfigId() != verificationConfigId) revert ConfigIdMismatch();

        console.log("Deployment verification completed successfully!");
        console.log("Next step: Calculate actual scope using deployed address and call setScope()");
    }
}

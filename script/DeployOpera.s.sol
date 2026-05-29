// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { OperaSelfSBT } from "../src/OperaSBT.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts-v2/contracts/interfaces/IIdentityVerificationHubV2.sol";
import { SelfUtils } from "../src/libraries/SelfUtils.sol";
import { BaseScript } from "./Base.s.sol";
import { console } from "forge-std/console.sol";

/// @title DeployOpera
/// @notice Deployment script for OperaSelfSBT contract
contract DeployOpera is BaseScript {
    error DeploymentFailed();
    error OwnerMismatch();
    error ValidityPeriodMismatch();
    error ConfigIdMismatch();

    /// @notice Main deployment function
    /// @return sbt The deployed OperaSelfSBT contract instance
    /// @dev Requires the following environment variables:
    ///      - IDENTITY_VERIFICATION_HUB_ADDRESS: Address of the Self Protocol verification hub
    ///      - SCOPE_SEED: Scope seed string (must match frontend Self SDK)
    ///      Optional environment variables:
    ///      - OWNER_ADDRESS: Contract owner (defaults to broadcaster)
    ///      - VALIDITY_PERIOD: Token validity period in seconds (defaults to 180 days)
    ///      - VERIFICATION_CONFIG_ID: Skip config registration and use this ID directly
    function run() public broadcast returns (OperaSelfSBT sbt) {
        address hubAddress = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        string memory scopeSeed = vm.envString("SCOPE_SEED");
        address owner = vm.envOr("OWNER_ADDRESS", broadcaster);
        uint256 validityPeriod = vm.envOr("VALIDITY_PERIOD", uint256(180 days));

        bytes32 verificationConfigId = vm.envOr("VERIFICATION_CONFIG_ID", bytes32(0));

        if (verificationConfigId == bytes32(0)) {
            verificationConfigId = _registerVerificationConfig(hubAddress);
        }

        // Deploy with placeholder scope (need deployed address to calculate real scope)
        sbt = new OperaSelfSBT(hubAddress, 1, owner, validityPeriod, verificationConfigId);

        // Calculate and set the real scope using Poseidon hash
        uint256 scope = SelfUtils.calculateScope(address(sbt), scopeSeed);
        sbt.setScope(scope);

        console.log("OperaSelfSBT deployed to:", address(sbt));
        console.log("Identity Verification Hub:", hubAddress);
        console.log("Owner:", owner);
        console.log("Scope Seed:", scopeSeed);
        console.log("Scope:", scope);
        console.log("Validity Period (seconds):", validityPeriod);
        console.log("Verification Config ID:", vm.toString(verificationConfigId));

        if (address(sbt) == address(0)) revert DeploymentFailed();
        if (sbt.owner() != owner) revert OwnerMismatch();
        if (sbt.validityPeriod() != validityPeriod) revert ValidityPeriodMismatch();
        if (sbt.verificationConfigId() != verificationConfigId) revert ConfigIdMismatch();

        console.log("Deployment verification completed successfully!");
    }

    function _registerVerificationConfig(address hubAddress) internal returns (bytes32) {
        string[] memory forbiddenCountries = new string[](4);
        forbiddenCountries[0] = "CUB";
        forbiddenCountries[1] = "IRN";
        forbiddenCountries[2] = "PRK";
        forbiddenCountries[3] = "SYR";

        SelfUtils.UnformattedVerificationConfigV2 memory config = SelfUtils.UnformattedVerificationConfigV2({
            olderThan: 0,
            forbiddenCountries: forbiddenCountries,
            ofacEnabled: true
        });

        bytes32 configId = IIdentityVerificationHubV2(hubAddress)
            .setVerificationConfigV2(SelfUtils.formatVerificationConfigV2(config));
        console.log("Registered verification config (OFAC + excluded countries)");
        return configId;
    }
}

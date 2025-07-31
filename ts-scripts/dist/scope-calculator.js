#!/usr/bin/env node
"use strict";
/**
 * SelfSBTV2 Scope Calculator
 *
 * This script calculates the scope value using the deployed contract address
 * and hashing it with the scope seed. Used for post-deployment scope calculation.
 *
 * Usage:
 *   npm run calculate-scope
 *
 * Environment variables required:
 *   - DEPLOYED_ADDRESS: The deployed contract address (for post-deployment calculation)
 *   - SCOPE_SEED: The scope seed value to hash with the deployed address
 *
 * Alternative usage (for testing):
 *   - PREDICTED_ADDRESS: A predicted address to use for scope calculation
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateEthereumAddress = validateEthereumAddress;
exports.validateScope = validateScope;
exports.validateBytes32 = validateBytes32;
const core_1 = require("@selfxyz/core");
// Removed CREATE2 prediction logic - now handled by Foundry script
// Load and validate environment variables
function loadEnvironmentConfig() {
    const deployedAddress = process.env.DEPLOYED_ADDRESS;
    const predictedAddress = process.env.PREDICTED_ADDRESS;
    const scopeSeed = process.env.SCOPE_SEED;
    // Use DEPLOYED_ADDRESS if available, otherwise fall back to PREDICTED_ADDRESS
    const contractAddress = deployedAddress || predictedAddress;
    // Validate required environment variables
    if (!contractAddress) {
        console.error('❌ Missing required environment variable:');
        console.error('   - Either DEPLOYED_ADDRESS or PREDICTED_ADDRESS must be provided');
        process.exit(1);
    }
    if (!scopeSeed) {
        console.error('❌ Missing required environment variable:');
        console.error('   - SCOPE_SEED');
        process.exit(1);
    }
    return {
        contractAddress: contractAddress,
        scopeSeed: scopeSeed
    };
}
async function main() {
    console.log('🧮 SelfSBTV2 Scope Calculator\n');
    // Load environment variables
    const config = loadEnvironmentConfig();
    const addressType = process.env.DEPLOYED_ADDRESS ? 'Deployed' : 'Predicted';
    console.log('📋 Configuration:');
    console.log(`   ${addressType} Address: ${config.contractAddress}`);
    console.log(`   Scope Seed: "${config.scopeSeed}"\n`);
    // Calculate scope value using contract address (using official @selfxyz/core implementation)
    const scopeValue = (0, core_1.hashEndpointWithScope)(config.contractAddress, config.scopeSeed);
    console.log(`🎯 Calculated Scope Value: ${scopeValue}`);
    // Output final results for GitHub workflow parsing
    console.log(`\nResults:`);
    console.log(`Scope Value: ${scopeValue}`);
    console.log(`Contract Address: ${config.contractAddress}`);
    if (process.env.DEPLOYED_ADDRESS) {
        console.log(`\n🔧 Next Step: Call setScope() Function`);
        console.log(`   Call setScope(${scopeValue}) on the deployed contract`);
        console.log(`   Contract Address: ${config.contractAddress}`);
    }
    else {
        console.log(`\n🚀 Ready for Contract Deployment!`);
        console.log(`   Deploy with placeholder scope, then call setScope(${scopeValue})`);
    }
}
// Validation functions
function validateEthereumAddress(addr) {
    const ethRegex = /^0x[a-fA-F0-9]{40}$/;
    return ethRegex.test(addr);
}
function validateScope(scopeValue) {
    const scopeRegex = /^[a-z0-9\s\-_.,!?]*$/;
    return scopeRegex.test(scopeValue) && scopeValue.length <= 20;
}
function validateBytes32(value) {
    const bytes32Regex = /^0x[a-fA-F0-9]{64}$/;
    return bytes32Regex.test(value);
}
// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}
//# sourceMappingURL=scope-calculator.js.map
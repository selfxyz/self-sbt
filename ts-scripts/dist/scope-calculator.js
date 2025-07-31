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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashEndpointWithScope = hashEndpointWithScope;
exports.validateEthereumAddress = validateEthereumAddress;
exports.validateScope = validateScope;
exports.validateBytes32 = validateBytes32;
const crypto = __importStar(require("crypto"));
// Hash function for scope calculation (copied from @selfxyz/core functionality)
function hashEndpointWithScope(endpoint, scope) {
    const encoder = new TextEncoder();
    const endpointBytes = encoder.encode(endpoint);
    const scopeBytes = encoder.encode(scope);
    // Concatenate endpoint and scope
    const combined = new Uint8Array(endpointBytes.length + scopeBytes.length);
    combined.set(endpointBytes);
    combined.set(scopeBytes, endpointBytes.length);
    // Create SHA-256 hash
    const hash = crypto.createHash('sha256').update(combined).digest();
    // Convert to hex string
    return '0x' + hash.toString('hex');
}
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
    // Calculate scope value using contract address
    const scopeValue = hashEndpointWithScope(config.contractAddress, config.scopeSeed);
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
#!/usr/bin/env node
"use strict";
/**
 * SelfSBTV2 Scope Calculator
 *
 * This script calculates the scope value by predicting the CREATE2 address and
 * hashing it with the scope seed. The Foundry script uses the same CREATE2 logic
 * for deterministic deployment.
 *
 * Usage:
 *   npm run calculate-scope
 *
 * Environment variables required:
 *   - DEPLOYER_ADDRESS: Address that will deploy the contract
 *   - IDENTITY_VERIFICATION_HUB_ADDRESS: Address of the verification hub
 *   - OWNER_ADDRESS: Address that will own the contract
 *   - VERIFICATION_CONFIG_ID: Verification configuration ID (bytes32)
 *   - VALIDITY_PERIOD: Token validity period in seconds (optional, defaults to 180 days)
 *   - SCOPE_SEED: The scope seed value to hash with the predicted address
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
exports.predictCreate2Address = predictCreate2Address;
exports.generateSalt = generateSalt;
exports.getInitCodeHash = getInitCodeHash;
exports.validateEthereumAddress = validateEthereumAddress;
exports.validateScope = validateScope;
exports.validateBytes32 = validateBytes32;
const ethers_1 = require("ethers");
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
// CREATE2 address prediction matching Foundry script logic
function predictCreate2Address(deployerAddress, salt, initCodeHash) {
    const deployerBytes = ethers_1.ethers.getBytes(deployerAddress);
    const saltBytes = ethers_1.ethers.getBytes(salt);
    const initCodeHashBytes = ethers_1.ethers.getBytes(initCodeHash);
    // CREATE2 formula: keccak256(0xff ++ deployer_address ++ salt ++ keccak256(init_code))
    const data = ethers_1.ethers.concat([
        '0xff',
        deployerBytes,
        saltBytes,
        initCodeHashBytes
    ]);
    const hash = ethers_1.ethers.keccak256(data);
    return ethers_1.ethers.getAddress('0x' + hash.slice(-40));
}
// Generate salt matching Foundry script logic
function generateSalt(scopeSeed) {
    return ethers_1.ethers.keccak256(ethers_1.ethers.toUtf8Bytes(`SelfSBTV2_${scopeSeed}`));
}
// Get the init code hash for SelfSBTV2
function getInitCodeHash(constructorArgs) {
    // Note: This is a simplified approach. For production, you'd need the actual
    // compiled bytecode from Foundry.
    console.log('⚠️  Warning: Using simplified init code hash calculation.');
    console.log('   For production use, get the actual bytecode from forge.');
    // Encode constructor arguments
    const abiCoder = ethers_1.ethers.AbiCoder.defaultAbiCoder();
    const encodedArgs = abiCoder.encode(['address', 'uint256', 'address', 'uint256', 'bytes32'], constructorArgs);
    // Placeholder: In reality, you'd get this from: forge inspect SelfSBTV2 bytecode
    const mockBytecode = '0x608060405234801561001057600080fd5b50'; // Placeholder
    const initCode = mockBytecode + encodedArgs.slice(2);
    return ethers_1.ethers.keccak256(initCode);
}
// Load and validate environment variables
function loadEnvironmentConfig() {
    const deployerAddress = process.env.DEPLOYER_ADDRESS;
    const hubAddress = process.env.IDENTITY_VERIFICATION_HUB_ADDRESS;
    const ownerAddress = process.env.OWNER_ADDRESS;
    const verificationConfigId = process.env.VERIFICATION_CONFIG_ID;
    const validityPeriod = process.env.VALIDITY_PERIOD || (180 * 24 * 60 * 60).toString(); // 180 days
    const scopeSeed = process.env.SCOPE_SEED;
    // Validate required environment variables
    const required = {
        'DEPLOYER_ADDRESS': deployerAddress,
        'IDENTITY_VERIFICATION_HUB_ADDRESS': hubAddress,
        'OWNER_ADDRESS': ownerAddress,
        'VERIFICATION_CONFIG_ID': verificationConfigId,
        'SCOPE_SEED': scopeSeed
    };
    const missing = Object.entries(required).filter(([, value]) => !value).map(([key]) => key);
    if (missing.length > 0) {
        console.error('❌ Missing required environment variables:');
        missing.forEach(key => console.error(`   - ${key}`));
        process.exit(1);
    }
    return {
        deployerAddress: deployerAddress,
        hubAddress: hubAddress,
        ownerAddress: ownerAddress,
        verificationConfigId: verificationConfigId,
        validityPeriod,
        scopeSeed: scopeSeed
    };
}
async function main() {
    console.log('🧮 SelfSBTV2 Scope Calculator\n');
    // Load environment variables
    const config = loadEnvironmentConfig();
    console.log('📋 Configuration:');
    console.log(`   Deployer: ${config.deployerAddress}`);
    console.log(`   Hub Address: ${config.hubAddress}`);
    console.log(`   Owner: ${config.ownerAddress}`);
    console.log(`   Verification Config ID: ${config.verificationConfigId}`);
    console.log(`   Validity Period: ${config.validityPeriod} seconds`);
    console.log(`   Scope Seed: "${config.scopeSeed}"\n`);
    // Step 1: Generate salt (same as Foundry script)
    const salt = generateSalt(config.scopeSeed);
    console.log(`🧂 Generated Salt: ${salt}`);
    // Step 2: Predict CREATE2 address
    const constructorArgs = [
        config.hubAddress,
        '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder scope
        config.ownerAddress,
        config.validityPeriod,
        config.verificationConfigId
    ];
    const initCodeHash = getInitCodeHash(constructorArgs);
    const predictedAddress = predictCreate2Address(config.deployerAddress, salt, initCodeHash);
    console.log(`🔮 Predicted CREATE2 Address: ${predictedAddress}`);
    // Step 3: Calculate scope value
    const scopeValue = hashEndpointWithScope(predictedAddress, config.scopeSeed);
    console.log(`🎯 Calculated Scope Value: ${scopeValue}`);
    // Step 4: Output final results for GitHub workflow parsing
    console.log(`\nResults:`);
    console.log(`Scope Value: ${scopeValue}`);
    console.log(`Predicted Address: ${predictedAddress}`);
    console.log(`Salt: ${salt}`);
    console.log(`\n🚀 Ready for Foundry Deployment!`);
    console.log(`   The Foundry script will use CREATE2 with the same salt to deploy to: ${predictedAddress}`);
    console.log(`   Make sure to set SCOPE_VALUE=${scopeValue} in your environment.`);
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
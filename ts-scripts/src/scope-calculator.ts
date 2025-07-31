#!/usr/bin/env node

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

import { ethers } from 'ethers';
import * as crypto from 'crypto';

// Types
interface EnvironmentConfig {
    predictedAddress: string;
    scopeSeed: string;
}

// Hash function for scope calculation (copied from @selfxyz/core functionality)
export function hashEndpointWithScope(endpoint: string, scope: string): string {
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
function loadEnvironmentConfig(): EnvironmentConfig {
    const predictedAddress = process.env.PREDICTED_ADDRESS;
    const scopeSeed = process.env.SCOPE_SEED;
    
    // Validate required environment variables
    const required: Record<string, string | undefined> = {
        'PREDICTED_ADDRESS': predictedAddress,
        'SCOPE_SEED': scopeSeed
    };
    
    const missing = Object.entries(required).filter(([, value]) => !value).map(([key]) => key);
    if (missing.length > 0) {
        console.error('❌ Missing required environment variables:');
        missing.forEach(key => console.error(`   - ${key}`));
        process.exit(1);
    }
    
    return {
        predictedAddress: predictedAddress!,
        scopeSeed: scopeSeed!
    };
}

async function main(): Promise<void> {
    console.log('🧮 SelfSBTV2 Scope Calculator\n');
    
    // Load environment variables
    const config = loadEnvironmentConfig();
    
    console.log('📋 Configuration:');
    console.log(`   Predicted Address: ${config.predictedAddress}`);
    console.log(`   Scope Seed: "${config.scopeSeed}"\n`);
    
    // Calculate scope value using predicted address from Foundry
    const scopeValue = hashEndpointWithScope(config.predictedAddress, config.scopeSeed);
    console.log(`🎯 Calculated Scope Value: ${scopeValue}`);
    
    // Output final results for GitHub workflow parsing
    console.log(`\nResults:`);
    console.log(`Scope Value: ${scopeValue}`);
    console.log(`Predicted Address: ${config.predictedAddress}`);
    
    console.log(`\n🚀 Ready for Foundry Deployment!`);
    console.log(`   The Foundry script will deploy to the predicted address: ${config.predictedAddress}`);
    console.log(`   Using calculated scope value: ${scopeValue}`);
}

// Validation functions
export function validateEthereumAddress(addr: string): boolean {
    const ethRegex = /^0x[a-fA-F0-9]{40}$/;
    return ethRegex.test(addr);
}

export function validateScope(scopeValue: string): boolean {
    const scopeRegex = /^[a-z0-9\s\-_.,!?]*$/;
    return scopeRegex.test(scopeValue) && scopeValue.length <= 20;
}

export function validateBytes32(value: string): boolean {
    const bytes32Regex = /^0x[a-fA-F0-9]{64}$/;
    return bytes32Regex.test(value);
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}
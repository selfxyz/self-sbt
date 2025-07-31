#!/usr/bin/env node

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

import { ethers } from 'ethers';
import * as crypto from 'crypto';

// Types
interface EnvironmentConfig {
    contractAddress: string;
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

async function main(): Promise<void> {
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
    } else {
        console.log(`\n🚀 Ready for Contract Deployment!`);
        console.log(`   Deploy with placeholder scope, then call setScope(${scopeValue})`);
    }
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
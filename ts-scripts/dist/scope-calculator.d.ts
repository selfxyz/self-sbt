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
export declare function hashEndpointWithScope(endpoint: string, scope: string): string;
export declare function validateEthereumAddress(addr: string): boolean;
export declare function validateScope(scopeValue: string): boolean;
export declare function validateBytes32(value: string): boolean;
//# sourceMappingURL=scope-calculator.d.ts.map
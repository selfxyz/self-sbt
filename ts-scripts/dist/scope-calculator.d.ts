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
export declare function hashEndpointWithScope(endpoint: string, scope: string): string;
export declare function predictCreate2Address(deployerAddress: string, salt: string, initCodeHash: string): string;
export declare function generateSalt(scopeSeed: string): string;
export declare function getInitCodeHash(constructorArgs: [string, string, string, string, string]): string;
export declare function validateEthereumAddress(addr: string): boolean;
export declare function validateScope(scopeValue: string): boolean;
export declare function validateBytes32(value: string): boolean;
//# sourceMappingURL=scope-calculator.d.ts.map
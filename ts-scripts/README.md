# SelfSBTV2 Scope Calculator

This directory contains the scope calculator for SelfSBTV2 CREATE2 deployments. It predicts the CREATE2 address and
calculates the scope value needed for deployment.

## Overview

The SelfSBTV2 contract requires a `scopeValue` parameter in its constructor, which should be calculated by hashing the
contract's address with a user-provided scope seed. However, this creates a circular dependency: you need the address to
calculate the scope, but you need the scope to deploy to a predictable address.

This is solved by:

1. **TypeScript Calculator**: Predicts the CREATE2 address and calculates the scope value
2. **Foundry Deployment**: Uses CREATE2 with the same salt for deterministic deployment
3. Both use the same salt generation logic ensuring the address matches the prediction

## Files

- `src/scope-calculator.ts` - CREATE2 address prediction and scope calculation
- `tsconfig.json` - TypeScript configuration
- `package.json` - Dependencies and scripts
- `README.md` - This documentation

## Installation

```bash
cd ts-scripts
npm install
```

## Usage

### Environment Variables

Set environment variables and run the scope calculator:

```bash
export DEPLOYER_ADDRESS="0x1234567890123456789012345678901234567890"
export IDENTITY_VERIFICATION_HUB_ADDRESS="0x0123456789012345678901234567890123456789"
export OWNER_ADDRESS="0x9876543210987654321098765432109876543210"
export VERIFICATION_CONFIG_ID="0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
export VALIDITY_PERIOD="15552000"  # 180 days in seconds
export SCOPE_SEED="my-scope-seed"

npm run dev
# or for compiled version
npm run calculate-scope
```

## Output

The tools will provide:

1. **Predicted Contract Address** - Where the contract will be deployed
2. **Calculated Scope Value** - The scope parameter for the constructor
3. **Deployment Parameters** - All parameters needed for deployment
4. **Environment Variables** - Ready-to-use export commands
5. **Forge Command** - Complete deployment command

Example output:

```
🎉 Final Results:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Contract Address:     0xabc123def456...
Scope Value:          0x789abc123def...
Salt:                 0x456def789abc...
Deployer:             0x123456789012...
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🛠️  Environment Variables for Deployment:
export IDENTITY_VERIFICATION_HUB_ADDRESS="0x..."
export SCOPE_VALUE="0x..."
export OWNER_ADDRESS="0x..."
export VALIDITY_PERIOD="15552000"
export VERIFICATION_CONFIG_ID="0x..."

🚀 Deployment Command:
forge script script/DeployV2.s.sol:DeployV2 --rpc-url <RPC_URL> --broadcast --verify
```

## Validation

The tools include validation for:

- ✅ Ethereum addresses (proper format and checksum)
- ✅ Scope seeds (lowercase ASCII, max 20 characters)
- ✅ Bytes32 values (proper hex format)
- ✅ Numeric values (positive integers)

## How It Works

### CREATE2 Address Prediction

The tools use the CREATE2 formula:

```
address = keccak256(0xff ++ deployer_address ++ salt ++ keccak256(init_code))[12:]
```

Where:

- `deployer_address` is the address that will deploy the contract
- `salt` is a bytes32 value for deterministic deployment
- `init_code` is the contract bytecode + constructor arguments

### Scope Calculation

The scope value is calculated using the same logic as the tools repository:

```javascript
function hashEndpointWithScope(endpoint, scope) {
  // Concatenate endpoint (contract address) and scope seed
  // Create SHA-256 hash
  // Return as hex string
}
```

### Iterative Refinement

Since the scope value depends on the contract address, and the contract address depends on the scope value, the tools
use iterative refinement to converge on the correct values.

## Important Notes

⚠️ **Production Usage**: The current implementation uses placeholder bytecode for demonstration. For production use,
you'll need to:

1. Get the actual compiled bytecode of SelfSBTV2
2. Update the `getInitCodeHash` function with real bytecode
3. Test on a testnet before mainnet deployment

⚠️ **Parameter Consistency**: The deployment must use the exact same parameters that were used for prediction, or the
addresses will not match.

⚠️ **CREATE2 vs CREATE**: This only works if you deploy using CREATE2. Standard CREATE deployments have different
addresses based on nonce.

## Integration with Existing Deployment

The predicted values can be used directly with the existing `DeployV2.s.sol` script:

```bash
# Use the environment variables from the prediction output
forge script script/DeployV2.s.sol:DeployV2 --rpc-url $RPC_URL --broadcast
```

## Troubleshooting

### Address Mismatch

If the predicted address doesn't match the actual deployment:

- Verify all parameters are identical
- Check that CREATE2 is being used for deployment
- Ensure the bytecode hash is correct

### Scope Validation Errors

- Scope seeds must be lowercase ASCII only
- Maximum 20 characters
- Allowed characters: `a-z`, `0-9`, spaces, `-`, `_`, `.`, `,`, `!`, `?`

### Dependencies

If you encounter module errors:

```bash
cd ts-scripts
npm install
npm run build
```

## Advanced Usage

### GitHub Actions Integration

The tools are designed to work seamlessly in CI/CD environments. Set your environment variables in GitHub Actions
secrets and run:

```yaml
- name: Predict Contract Address
  env:
    DEPLOYER_ADDRESS: ${{ secrets.DEPLOYER_ADDRESS }}
    IDENTITY_VERIFICATION_HUB_ADDRESS: ${{ secrets.HUB_ADDRESS }}
    OWNER_ADDRESS: ${{ secrets.OWNER_ADDRESS }}
    VERIFICATION_CONFIG_ID: ${{ secrets.CONFIG_ID }}
    VALIDITY_PERIOD: "15552000"
    SCOPE_SEED: "production-scope"
  run: |
    cd ts-scripts
    npm install
    npm run predict
```

### Library Usage

The functions can also be imported and used programmatically:

```typescript
import { hashEndpointWithScope, predictCreate2Address } from "./src/deploy-predictor";

const scopeValue = hashEndpointWithScope("0x123...", "my-scope");
const address = predictCreate2Address("0xdeployer...", "0xsalt...", "0xhash...");
```

## Contributing

When modifying these tools:

1. Maintain compatibility with the existing ScopeGenerator in the tools repository
2. Keep validation logic consistent
3. Test thoroughly on testnets
4. Update documentation for any API changes

# GitHub Secrets Configuration

This document outlines the GitHub secrets required for the SelfSBTV2 deployment workflow.

## Required Secrets

### `DEFAULT_DEPLOYER_PRIVATE_KEY`

- **Purpose**: Default deployer account for internal deployments
- **Format**: Ethereum private key (64 hex characters)
- **Example**: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- **Required**: ✅ Yes
- **Used When**: Users don't provide a custom deployer private key

## Optional Secrets

### `CELOSCAN_API_KEY`

- **Purpose**: Contract verification on Celo networks (Mainnet & Alfajores)
- **Format**: API key string
- **Example**: `ABC123XYZ789DEF456GHI`
- **Required**: ❌ No (but recommended for contract verification)
- **Used When**: Deploying to Celo Mainnet or Alfajores
- **Get API Key**: [celoscan.io/apis](https://celoscan.io/apis)

## How to Set Secrets

1. **Navigate to Repository Settings**

   - Go to your GitHub repository
   - Click **Settings** tab
   - Select **Secrets and variables** → **Actions**

2. **Add New Secret**

   - Click **"New repository secret"**
   - Enter the secret name exactly as shown above
   - Paste the secret value
   - Click **"Add secret"**

3. **Verify Secrets**
   - Ensure secret names match exactly (case-sensitive)
   - Secrets should appear in the repository secrets list

## Network-Specific Information

The workflow automatically handles network-specific configurations:

### Celo Mainnet

- **Hub Address**: `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF` (predefined)
- **RPC URL**: `https://forno.celo.org` (predefined)
- **Block Explorer**: Uses `CELOSCAN_API_KEY` for verification

### Celo Alfajores (Testnet)

- **Hub Address**: `0x68c931C9a534D37aa78094877F46fE46a49F1A51` (predefined)
- **RPC URL**: `https://alfajores-forno.celo-testnet.org` (predefined)
- **Block Explorer**: Uses `CELOSCAN_API_KEY` for verification

## Security Best Practices

- ✅ **Never commit secrets** to code or documentation
- ✅ **Use dedicated deployer accounts** with minimal permissions
- ✅ **Rotate keys regularly** for production deployments
- ✅ **Monitor deployment transactions** on block explorers
- ⚠️ **Test on testnet first** before mainnet deployments

## Troubleshooting

### Common Issues

**Secret Not Found Error**

```
Error: Secret DEFAULT_DEPLOYER_PRIVATE_KEY not found
```

**Solution**: Ensure the secret name is exactly `DEFAULT_DEPLOYER_PRIVATE_KEY`

**Invalid Private Key Error**

```
Error: Invalid private key format
```

**Solution**: Ensure private key is 64 hex characters (without or with `0x` prefix)

**Contract Verification Failed**

```
Warning: Contract verification failed
```

**Solution**: Check `CELOSCAN_API_KEY` is valid and has sufficient quota

## Summary

**Minimum Setup** (for basic deployment):

- `DEFAULT_DEPLOYER_PRIVATE_KEY` ✅

**Recommended Setup** (with verification):

- `DEFAULT_DEPLOYER_PRIVATE_KEY` ✅
- `CELOSCAN_API_KEY` ✅

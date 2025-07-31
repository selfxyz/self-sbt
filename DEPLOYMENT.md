# SelfSBTV2 Complete Deployment Guide

This guide covers the complete deployment pipeline for SelfSBTV2, which integrates TypeScript scope prediction with
Foundry contract deployment.

## 🚀 Quick Start Options

### Option 1: GitHub Actions (Recommended - No Cloning Required)

The easiest way to deploy is using GitHub Actions directly from the web interface:

1. **Navigate to the Actions tab** in the GitHub repository
2. **Select "Deploy SelfSBTV2"** workflow
3. **Click "Run workflow"** button
4. **Fill in the required parameters**:

   - **Network**: Choose from Celo Mainnet or Celo Alfajores (testnet)
   - **Owner Address**: Address that will own the deployed contract
   - **Verification Config ID**: bytes32 verification configuration ID
   - **Scope Seed**: The scope identifier you use in your frontend Self SDK (max 20 chars, lowercase)
   - **Custom Deployer Private Key**: Optional custom deployer (uses default deployer if not provided)
   - **Validity Period**: Token validity in seconds (optional, defaults to 180 days)

5. **Click "Run workflow"** to start deployment

The workflow will:

- ✅ Validate all inputs
- 🔮 Generate scope value and predict contract address
- 🚀 Deploy the contract using Foundry
- 📋 Verify the contract (if API key provided)
- 📊 Create a deployment summary with all details

### Option 2: Local Deployment with Bash Script

For local deployment with full control:

```bash
# Clone the repository
git clone https://github.com/selfxyz/self-sbt.git
cd self-sbt

# Set environment variables
export DEPLOYER_ADDRESS="0x1234567890123456789012345678901234567890"
export OWNER_ADDRESS="0x9876543210987654321098765432109876543210"
export VERIFICATION_CONFIG_ID="0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
export SCOPE_SEED="production"
export VALIDITY_PERIOD="15552000"  # Optional, 180 days

# Network is automatically configured (celo-mainnet or celo-alfajores)
# Hub addresses and RPC URLs are predefined for supported networks

# Run the deployment
./deploy.sh
```

### Option 3: Manual Step-by-Step

For development or custom deployments:

```bash
# 1. Install dependencies and generate scope
cd ts-scripts
npm install
npm run dev  # Uses environment variables

# 2. Note the generated SCOPE_VALUE from output

# 3. Deploy with Foundry
cd ..
export SCOPE_VALUE="0x..." # Use value from step 2
forge script script/DeployV2.s.sol:DeployV2 --rpc-url $RPC_URL --broadcast
```

## 📋 Parameters

### Required Parameters

| Parameter                  | Description                                  | Example        | Required |
| -------------------------- | -------------------------------------------- | -------------- | -------- |
| **NETWORK**                | Target deployment network                    | `celo-mainnet` | ✅       |
| **OWNER_ADDRESS**          | Contract owner address                       | `0x789...`     | ✅       |
| **VERIFICATION_CONFIG_ID** | Verification config (bytes32)                | `0xabcd...`    | ✅       |
| **SCOPE_SEED**             | Scope identifier from your frontend Self SDK | `"my-app"`     | ✅       |

### Optional Parameters

| Parameter                       | Description              | Default               |
| ------------------------------- | ------------------------ | --------------------- |
| **CUSTOM_DEPLOYER_PRIVATE_KEY** | Custom deployer key      | Uses default deployer |
| **VALIDITY_PERIOD**             | Token validity (seconds) | `15552000` (180 days) |

### Predefined Network Configurations

#### Celo Mainnet

- **Hub Address**: `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF`
- **RPC URL**: `https://forno.celo.org`
- **Chain ID**: `42220`
- **Block Explorer**: `https://celoscan.io`

#### Celo Alfajores (Testnet)

- **Hub Address**: `0x68c931C9a534D37aa78094877F46fE46a49F1A51`
- **RPC URL**: `https://alfajores-forno.celo-testnet.org`
- **Chain ID**: `44787`
- **Block Explorer**: `https://alfajores.celoscan.io`

## 📝 Understanding Scope Seed

The **Scope Seed** is a crucial parameter that connects your deployed contract with your frontend application:

- **What it is**: A unique identifier (string) that you define for your application
- **Where it's used**: In your frontend Self SDK when initializing verification
- **Example**: If your app is called "MyDApp", you might use `"mydapp"` as the scope seed
- **Requirements**: Max 20 characters, lowercase ASCII only (`a-z`, `0-9`, spaces, `-`, `_`, `.`, `,`, `!`, `?`)

**Frontend Integration Example:**

```javascript
// In your frontend Self SDK initialization
const selfSDK = new SelfSDK({
  scope: "mydapp", // This must match your deployment's scope seed
  // ... other config
});
```

The deployment pipeline automatically generates the cryptographic scope value by hashing your scope seed with the
predicted contract address.

## 🔍 Parameter Validation

The deployment pipeline validates all inputs:

- ✅ **Ethereum Addresses**: Must be valid format (`0x` + 40 hex chars)
- ✅ **Bytes32 Values**: Must be valid format (`0x` + 64 hex chars)
- ✅ **Scope Seeds**: Max 20 characters, lowercase ASCII only
- ✅ **Numeric Values**: Must be positive integers
- ✅ **Private Keys**: Automatically derived to addresses (never logged)

## 🔮 How It Works

### 1. Scope Generation Process

The TypeScript script solves the circular dependency:

```
Contract Address ←→ Scope Value
```

**Process:**

1. **Initial Prediction**: Predict address with placeholder scope
2. **Scope Calculation**: Hash predicted address + scope seed
3. **Final Prediction**: Predict address with actual scope
4. **Iterative Refinement**: Repeat until convergence

**Formula:**

```typescript
scopeValue = keccak256(predictedAddress + scopeSeed);
salt = keccak256("SelfSBTV2_" + scopeSeed);
predictedAddress = CREATE2(deployer, salt, initCodeHash);
```

### 2. Contract Deployment

Uses the existing `DeployV2.s.sol` Foundry script with the generated scope value:

```solidity
SelfSBTV2 sbt = new SelfSBTV2(
    hubAddress,           // Identity Verification Hub
    scopeValue,          // Generated scope value
    owner,               // Contract owner
    validityPeriod,      // Token validity period
    verificationConfigId // Verification configuration
);
```

## 🌐 Network Support

The deployment pipeline supports Celo networks with predefined configurations:

### Supported Networks

- **Celo Mainnet**: `https://forno.celo.org` (Chain ID: 42220)
- **Celo Alfajores**: `https://alfajores-forno.celo-testnet.org` (Chain ID: 44787)

All network configurations including hub addresses, RPC URLs, and block explorers are automatically configured based on
your network selection.

## 🔐 Security Considerations

### Private Key Handling

- ✅ **Default Deployer**: Repository uses a default deployer stored in GitHub secrets
- ✅ **Custom Deployer**: Optionally provide your own deployer private key
- ⚠️ **Never commit private keys** to version control
- ✅ **Private keys are never logged** in workflows
- ✅ **Use hardware wallets** for production deployments

### Repository Secrets Setup

For repository maintainers, configure these GitHub secrets:

#### Required Secrets

- `DEFAULT_DEPLOYER_PRIVATE_KEY` - Default deployer private key for internal use

#### Optional Secrets (for contract verification)

- `CELOSCAN_API_KEY` - Celoscan API key for verifying contracts on Celo networks

#### How to Set GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Add each secret with the exact name and value

**Example Secret Values:**

```
DEFAULT_DEPLOYER_PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
CELOSCAN_API_KEY=ABC123XYZ789DEF456GHI
```

### Deployer Options

1. **Default Deployer** (Recommended for internal use):

   - Uses `DEFAULT_DEPLOYER_PRIVATE_KEY` from repository secrets
   - No need to provide private key in workflow inputs
   - Suitable for team/internal deployments

2. **Custom Deployer** (For external users):
   - Provide custom private key in workflow input
   - Useful when specific deployer address is required
   - Private key is masked and never logged

### Verification

- ✅ **Always verify** predicted vs actual addresses match
- ✅ **Test on testnets** before mainnet deployment
- ✅ **Use contract verification** for transparency
- ✅ **Validate all parameters** before deployment

## 📊 Deployment Output

### Successful Deployment

```
🎉 Final Results:
Contract Address: 0xabc123def456789...
Scope Value: 0x789abc123def456...
Salt: 0x456def789abc123...

🛠️ Deployment Command:
IDENTITY_VERIFICATION_HUB_ADDRESS=0x... \
SCOPE_VALUE=0x... \
OWNER_ADDRESS=0x... \
VALIDITY_PERIOD=15552000 \
VERIFICATION_CONFIG_ID=0x... \
forge script script/DeployV2.s.sol:DeployV2 --rpc-url <RPC_URL> --broadcast

✅ Deployment verification completed successfully!
```

### GitHub Actions Summary

The workflow creates a detailed summary including:

- 📋 All deployment parameters
- 🎯 Predicted vs actual addresses
- 🔗 Block explorer links
- ⚠️ Important notes and next steps

## 🛠 Troubleshooting

### Common Issues

**Address Mismatch**

```
❌ Predicted address doesn't match deployed address
```

**Solution**: Verify all parameters are identical, check CREATE2 usage

**Invalid Scope Seed**

```
❌ Scope must contain only lowercase ASCII characters
```

**Solution**: Use only `a-z`, `0-9`, spaces, `-`, `_`, `.`, `,`, `!`, `?`

**Missing Dependencies**

```
❌ Node.js/Foundry not installed
```

**Solution**: Install required tools:

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**RPC Issues**

```
❌ Failed to connect to RPC endpoint
```

**Solution**: Check RPC URL, API keys, and network connectivity

### Debug Mode

For detailed debugging, run with verbose output:

```bash
# Local deployment with debug
DEBUG=1 ./deploy.sh

# TypeScript debug
cd ts-scripts
npm run dev 2>&1 | tee debug.log
```

## 📝 Best Practices

### Development Workflow

1. **Test on testnets first** (Sepolia, Mumbai, etc.)
2. **Use consistent scope seeds** across environments
3. **Verify contract addresses** match predictions
4. **Keep deployment records** for auditing

### Production Deployment

1. **Use GitHub Actions** for reproducibility
2. **Enable contract verification** with API keys
3. **Double-check all parameters** before deployment
4. **Monitor deployment transactions** on block explorers
5. **Test contract functionality** after deployment

### Security Checklist

- [ ] Private keys secured and never shared
- [ ] All parameters validated
- [ ] Test deployment on testnet
- [ ] Contract verification enabled
- [ ] Deployment transaction confirmed
- [ ] Contract functionality tested
- [ ] Deployment documented

## 🔄 Updates and Maintenance

### Updating the Deployment Pipeline

- **TypeScript Scripts**: Update in `ts-scripts/src/`
- **Foundry Scripts**: Update in `script/`
- **GitHub Workflows**: Update in `.github/workflows/`
- **Documentation**: Keep this file updated

### Version Control

- Tag releases with deployment pipeline versions
- Keep deployment artifacts for auditing
- Document breaking changes

## 🤝 Contributing

When modifying the deployment pipeline:

1. **Test thoroughly** on testnets
2. **Update documentation** for any changes
3. **Maintain backward compatibility** when possible
4. **Follow security best practices**
5. **Add appropriate validation** for new parameters

## 📞 Support

For deployment issues:

1. Check the troubleshooting section above
2. Review GitHub Actions workflow logs
3. Verify all parameters and network connectivity
4. Test on testnets before mainnet deployment

---

**⚠️ Important**: Always test deployments on testnets before mainnet. This deployment pipeline handles sensitive
operations and should be used with care.

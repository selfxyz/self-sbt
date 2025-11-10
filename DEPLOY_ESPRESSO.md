# EspressoSelfSBT Deployment Guide

## 🚀 Quick Start: Deploy via GitHub Actions

### Prerequisites
- Repository secrets configured:
  - `DEFAULT_DEPLOYER_PRIVATE_KEY` - Private key for deployment
  - `CELOSCAN_API_KEY` - API key for contract verification (optional)

### Steps

1. **Navigate to GitHub Actions**
   - Go to your repository on GitHub
   - Click on "Actions" tab
   - Select "Deploy EspressoSelfSBT" workflow

2. **Run Workflow**
   - Click "Run workflow" button
   - Fill in the required parameters:

#### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| **network** | Network to deploy on | `celo-alfajores` (testnet) or `celo-mainnet` |
| **owner_address** | Address that will own the contract | `0x1234...5678` |
| **verification_config_id** | Self Protocol verification config ID | `0x7b6436b0...` |
| **scope_seed** | Scope identifier from frontend | `espresso-brand` |

#### Optional Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| **custom_deployer_private_key** | Override default deployer | Uses `DEFAULT_DEPLOYER_PRIVATE_KEY` |
| **validity_period** | Token validity in seconds | `15552000` (180 days) |
| **placeholder_scope** | Initial scope value | `1` |

3. **Monitor Deployment**
   - Watch the workflow execution in real-time
   - Check deployment summary for contract address
   - View contract on CeloScan

4. **Post-Deployment**
   - Copy the deployed contract address
   - Update frontend configuration
   - Update indexer configuration (see below)

---

## 🛠️ Manual Deployment (Local)

### Prerequisites

```bash
# Install dependencies
pnpm install
forge install

# Setup environment variables
export IDENTITY_VERIFICATION_HUB_ADDRESS="0x68c931C9a534D37aa78094877F46fE46a49F1A51"  # Alfajores
export OWNER_ADDRESS="0x..."
export VERIFICATION_CONFIG_ID="0x7b6436b0c98f62380866d9432c2af0ee08ce16a171bda6951aecd95ee1307d61"
export VALIDITY_PERIOD="15552000"  # 180 days
export PLACEHOLDER_SCOPE="1"
```

### Deploy Contract

**Alfajores (Testnet)**:
```bash
forge script script/DeployEspresso.s.sol:DeployEspresso \
  --rpc-url https://alfajores-forno.celo-testnet.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

**Mainnet**:
```bash
forge script script/DeployEspresso.s.sol:DeployEspresso \
  --rpc-url https://forno.celo.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Calculate and Set Scope

```bash
# 1. Calculate scope value
cd ts-scripts
DEPLOYED_ADDRESS=<contract_address> pnpm run calculate-scope

# 2. Set scope on contract
cast send <contract_address> "setScope(uint256)" <scope_value> \
  --rpc-url <rpc_url> \
  --private-key $PRIVATE_KEY
```

---

## 📊 Post-Deployment: Indexer Configuration

After deploying EspressoSelfSBT, update the indexer to start tracking events.

### 1. Update `config.yaml`

**File**: `self-envio/self-sbt-v2-envio/config.yaml`

```yaml
networks:
- id: 42220  # Celo Mainnet
  start_block: <deployment_block>
  contracts:
  # ... existing contracts ...

  - name: EspressoSelfSBT
    address: <DEPLOYED_CONTRACT_ADDRESS>
```

### 2. Update `schema.graphql`

**File**: `self-envio/self-sbt-v2-envio/schema.graphql`

Add the following entity:

```graphql
type EspressoVerification {
  id: ID!                      # tx_hash_log_index
  celoAddress: String!          # User's Celo address (SBT holder)
  ethereumAddress: String!      # User's Ethereum address (for airdrop)
  nullifier: BigInt!            # Verification nullifier
  timestamp: BigInt!            # Verification timestamp
  blockNumber: BigInt!          # Block number
  transactionHash: String!      # Transaction hash
}
```

Optionally, add `ethereumAddress` to existing entities:

```graphql
type SBTHolder {
  # ... existing fields ...
  ethereumAddress: String  # For Espresso only (null for other brands)
}

type VerificationEvent {
  # ... existing fields ...
  ethereumAddress: String  # For Espresso only
}
```

### 3. Update Event Handlers

**File**: `self-envio/self-sbt-v2-envio/src/EventHandlers.ts`

Add the constant:

```typescript
const ESPRESSO_SELFSBT_ADDRESS = "<DEPLOYED_CONTRACT_ADDRESS>";
```

Update `getContractInfo()`:

```typescript
function getContractInfo(address: string): { name: string; address: string } {
  const normalizedAddress = address.toLowerCase();

  // ... existing contracts ...

  if (normalizedAddress === ESPRESSO_SELFSBT_ADDRESS.toLowerCase()) {
    return { name: "EspressoSelfSBT", address: ESPRESSO_SELFSBT_ADDRESS };
  }

  return { name: "UnknownContract", address: address };
}
```

Add event handler for `VerificationCompleted`:

```typescript
EspressoSelfSBT.VerificationCompleted.handler(async ({ event, context }) => {
  const contractInfo = getContractInfo(event.srcAddress);

  // Create EspressoVerification record
  const verificationId = `${event.transactionHash}_${event.logIndex}`;

  await context.EspressoVerification.set({
    id: verificationId,
    celoAddress: event.params.celoAddress.toLowerCase(),
    ethereumAddress: event.params.ethereumAddress.toLowerCase(),
    nullifier: event.params.nullifier,
    timestamp: event.params.timestamp,
    blockNumber: BigInt(event.blockNumber),
    transactionHash: event.transactionHash,
  });
});
```

### 4. Restart Indexer

```bash
cd self-envio/self-sbt-v2-envio
pnpm run dev  # or your deployment command
```

---

## 🔍 Verification

### Check Contract on CeloScan

**Alfajores**: https://alfajores.celoscan.io/address/<contract_address>
**Mainnet**: https://celoscan.io/address/<contract_address>

### Test Contract Functions

```bash
# Check owner
cast call <contract_address> "owner()" --rpc-url <rpc_url>

# Check validity period
cast call <contract_address> "validityPeriod()" --rpc-url <rpc_url>

# Check verification config ID
cast call <contract_address> "verificationConfigId()" --rpc-url <rpc_url>

# Check EIP-712 type hash
cast call <contract_address> "VERIFY_IDENTITY_TYPEHASH()" --rpc-url <rpc_url>
```

### Verify EIP-712 Type Hash

The type hash should match:
```
keccak256("VerifyIdentity(address wallet,uint256 timestamp,address ethereumAddress)")
```

Expected: `0x...` (calculate with `cast keccak "VerifyIdentity(address wallet,uint256 timestamp,address ethereumAddress)"`)

---

## 📝 Network Configurations

### Celo Mainnet
- **Chain ID**: 42220
- **RPC URL**: https://forno.celo.org
- **Explorer**: https://celoscan.io
- **Hub Address**: `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF`

### Celo Alfajores (Testnet)
- **Chain ID**: 44787
- **RPC URL**: https://alfajores-forno.celo-testnet.org
- **Explorer**: https://alfajores.celoscan.io
- **Hub Address**: `0x68c931C9a534D37aa78094877F46fE46a49F1A51`

---

## ❓ Troubleshooting

### Deployment fails with "Verification config does not exist"
- Check that `VERIFICATION_CONFIG_ID` is correct
- Verify the config exists in the hub for the target network

### Scope calculation fails
- Ensure `ts-scripts` dependencies are installed
- Check that `DEPLOYED_ADDRESS` environment variable is set
- Verify `scope_seed` matches frontend configuration

### Contract verification fails
- Ensure `CELOSCAN_API_KEY` is set
- Wait a few minutes and try manual verification on CeloScan
- Check constructor arguments match deployment parameters

### Indexer not capturing events
- Verify contract address in `config.yaml`
- Check event handler is registered for `VerificationCompleted`
- Ensure indexer is syncing from correct block number
- Check indexer logs for errors

---

## 🔗 Related Documentation

- [Self Protocol Documentation](https://docs.self.xyz)
- [Foundry Book](https://book.getfoundry.sh/)
- [Celo Documentation](https://docs.celo.org)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

## 🎯 Quick Reference

### Deployed Contracts

| Network | Contract Address | Deployment Date |
|---------|-----------------|-----------------|
| Alfajores | `TBD` | - |
| Mainnet | `TBD` | - |

*Update this table after deployment*

### Key Differences from SelfSBTV2

| Feature | SelfSBTV2 | EspressoSelfSBT |
|---------|-----------|-----------------|
| **EIP-712 Type** | `VerifyIdentity(address wallet,uint256 timestamp)` | `VerifyIdentity(address wallet,uint256 timestamp,address ethereumAddress)` |
| **UserContextData** | 97 bytes (signature + timestamp) | 117 bytes (signature + timestamp + ethereumAddress) |
| **Events** | `SBTMinted`, `SBTUpdated`, `SBTBurned` | + `VerificationCompleted` |
| **Purpose** | General identity verification | Espresso brand with airdrop tracking |

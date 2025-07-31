# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Commands

### Building and Testing
```bash
# Install dependencies
pnpm install && forge install

# Build contracts
forge build

# Run all tests (20 tests, should all pass)
forge test

# Run specific test patterns
forge test --match-test "test_VerifySelfProof_Case"  # Test specific verification cases
forge test --match-test "test_BurnSBT"              # Test owner functions
forge test -vvv                                     # Verbose output with stack traces

# Linting and formatting
pnpm lint                    # Run all linting (solhint + prettier)
forge fmt                    # Format Solidity code
pnpm prettier:write          # Format non-Solidity files
```

### TypeScript Tools
```bash
cd ts-scripts
pnpm install
pnpm run calculate-scope     # Calculate CREATE2 scope value for deployment
pnpm run build              # Compile TypeScript
```

### Deployment
```bash
# Quick automated deployment
./deploy.sh

# Manual deployment steps
cd ts-scripts && pnpm run calculate-scope  # Get scope value
forge script script/DeployV2.s.sol:DeployV2 --rpc-url $RPC_URL --broadcast
```

## Architecture Overview

### Contract Architecture
This is a **Soulbound Token (SBT)** implementation built on Self Protocol's zero-knowledge identity verification system. The architecture follows the **"one dApp ↔ one SBT"** model for privacy isolation.

**Core Contract: `SelfSBTV2`**
- Inherits from `SelfVerificationRoot` (Self's ZK verification)
- Inherits from `ERC5192` (soulbound token standard)
- Inherits from `Ownable` (admin controls)

**Key Mappings:**
- `_nullifierToTokenId`: Permanent binding between ZK nullifiers and token IDs
- `_userToTokenId`: Maps user addresses to their token (one SBT per user)
- `_expiryTimestamps`: Token expiration times

### Verification Logic Matrix
The contract handles four distinct scenarios based on nullifier usage and receiver token ownership:

| Nullifier Status | Receiver Has SBT | Action | Description |
|------------------|------------------|--------|-------------|
| NEW | NO | **MINT** | First-time verification |
| NEW | YES | **UPDATE** | New proof for existing user |
| USED | NO | **RECOVER/REVERT** | Recover burned token or reject |
| USED | YES | **CHECK OWNER** | Verify nullifier ownership |

### Deployment Architecture
**Hybrid TypeScript + Foundry System:**
1. **TypeScript Calculator** (`ts-scripts/`): Predicts CREATE2 address and calculates scope
2. **Foundry Scripts** (`script/`): Uses calculated values for deterministic deployment
3. **GitHub Actions**: Automated deployment pipeline with input validation

**Supported Networks:** Only Celo Mainnet and Celo Alfajores (testnet)

## Testing Architecture

**Test Strategy:** Comprehensive mock-based testing that simulates the Self Protocol verification flow.

**Key Testing Pattern:**
- Tests use `_simulateVerification()` helper that:
  1. Calls `verifySelfProof()` as the relayer
  2. Manually calls `onVerificationSuccess()` as the identity hub (mocked)
- Event testing requires `expectEmit` before the callback that emits events
- Revert testing requires `expectRevert` before the callback that reverts

**Critical Test Files:**
- `test/SelfSBTV2.t.sol`: All 20 tests covering the verification matrix and owner functions

## Development Patterns

### Mock Testing Pattern
When testing verification flows, the Identity Hub is mocked. The real flow is:
```solidity
// Real flow: relayer -> verifySelfProof -> hub.verify -> hub calls onVerificationSuccess
// Test flow: relayer -> verifySelfProof + manual onVerificationSuccess callback
```

### Error Handling
- `RegisteredNullifier()`: Nullifier misuse (Cases 3/4)
- `InvalidValidityPeriod()`: Zero validity period
- `TokenDoesNotExist()`: Operating on non-existent token
- `InvalidReceiver()`: Zero address receiver

### Owner Functions
- `burnSBT(tokenId)`: Remove user's token (enables recovery)
- `setValidityPeriod(seconds)`: Update token validity duration
- Only callable by contract owner (typically the dApp)

## Configuration

### Foundry Configuration
- **Solidity Version:** 0.8.28 (fixed, no auto-detection)
- **EVM Version:** paris (for broader compatibility)
- **Optimizer:** Enabled with 10,000 runs
- **Block Timestamp:** Fixed to Jan 1, 2025 for consistent testing

### Package Management
- **Main Project:** Uses pnpm (`pnpm-lock.yaml`)
- **TypeScript Tools:** Uses pnpm (`ts-scripts/pnpm-lock.yaml`)
- **GitHub Actions:** Uses pnpm with proper caching

### Network Configuration
Celo networks have predefined configurations:
- **Mainnet Hub:** `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF`
- **Alfajores Hub:** `0x68c931C9a534D37aa78094877F46fE46a49F1A51`

## Security Considerations

### Known Limitation: Nullifier Ambiguity Attack
Due to zero-knowledge properties, the system cannot distinguish between legitimate passport renewal (Case 2) and potential attacks where someone targets an existing wallet. This creates a theoretical attack vector requiring admin due diligence for burn requests.

### Recovery Model
- **Lost Passport:** Direct re-verification (no admin needed)
- **Lost Wallet:** Admin burn + recovery with same token ID
- **Permanent Nullifier Binding:** Each nullifier maps to one token ID forever

## Deployment Pipeline

### Environment Variables Required
```bash
DEPLOYER_ADDRESS          # Address deploying the contract
IDENTITY_VERIFICATION_HUB_ADDRESS  # Network-specific hub address
OWNER_ADDRESS            # Contract owner address
VERIFICATION_CONFIG_ID   # bytes32 verification config
SCOPE_SEED              # Scope identifier (max 20 chars, lowercase)
VALIDITY_PERIOD         # Optional, defaults to 180 days
```

### Deployment Flow
1. **Scope Calculation:** TypeScript predicts CREATE2 address and hashes with scope seed
2. **Contract Deployment:** Foundry uses calculated scope for deterministic deployment
3. **Verification:** Automatic contract verification on block explorers
4. **Validation:** Address prediction should match actual deployed address

The deployment system ensures deterministic addresses across environments using CREATE2 with calculated salt values.
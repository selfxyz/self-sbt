# SelfSBTV2 v1.0.0

Production-ready Soulbound Token implementation for privacy-preserving identity verification using Self Protocol's zero-knowledge infrastructure.

## What's New

### Core Features
- **Soulbound Token Implementation**: ERC5192-compliant non-transferable tokens with configurable validity periods
- **Self Protocol V2 Integration**: Zero-knowledge identity verification with anti-replay protection
- **Privacy Isolation**: One dApp ↔ one SBT model preventing cross-application tracking
- **Recovery System**: Comprehensive recovery workflows for lost wallets and passports

### Smart Contract Architecture
- Modular design inheriting from `SelfVerificationRoot`, `ERC5192`, and `Ownable`
- 4-case verification matrix handling all nullifier and user token scenarios
- Permanent nullifier binding with secure token recovery mechanisms
- Owner controls for token burning and validity period management

### Deployment Infrastructure
- **CREATE2 Deterministic Deployment**: Predictable contract addresses using calculated scope values
- **GitHub Actions Pipeline**: Automated deployment with contract verification on CeloScan
- **Multi-Network Support**: Configured for Celo Mainnet and Alfajores testnet
- **TypeScript Integration**: Hybrid TypeScript + Foundry system for accurate address prediction

## Technical Specifications

**Solidity Version**: 0.8.28  
**Dependencies**: OpenZeppelin 5.3.0, Self Protocol V2 contracts  
**Networks**: Celo Mainnet, Celo Alfajores  
**Testing**: 20+ comprehensive tests covering all verification cases

## Key Functions

```solidity
// Owner functions
function burnSBT(uint256 tokenId) external onlyOwner
function setValidityPeriod(uint256 newPeriod) external onlyOwner
function setScope(uint256 newScopeValue) external onlyOwner

// View functions
function isTokenValid(uint256 tokenId) external view returns (bool)
function getTokenIdByAddress(address user) external view returns (uint256)
function isNullifierUsed(uint256 nullifier) external view returns (bool)
```

## Breaking Changes

This release introduces SelfSBTV2 replacing the previous SelfPassportSBTV1 implementation:
- Upgraded to Self Protocol V2 contracts
- Enhanced verification logic with 4-case matrix
- Improved recovery mechanisms
- CREATE2-based deployment system

## Deployment

### Quick Start
```bash
./deploy.sh
```

### GitHub Actions
Use the "Deploy SelfSBTV2" workflow in the Actions tab with required parameters:
- Network (Celo Mainnet/Alfajores)
- Owner Address
- Verification Config ID
- Scope Seed

### Manual Deployment
```bash
cd ts-scripts && pnpm run calculate-scope
forge script script/DeployV2.s.sol:DeployV2 --rpc-url $RPC_URL --broadcast
```

## Security Considerations

**Known Limitation**: Due to zero-knowledge properties, the system cannot cryptographically distinguish between legitimate passport renewal and potential targeting attacks. Admin due diligence is required for all burn requests.

## Documentation

- Complete setup and integration guides in README.md
- Deployment instructions in DEPLOYMENT.md
- AI development context in CLAUDE.md

---

**Full Changelog**: https://github.com/selfxyz/self-sbt/compare/...v1.0.0
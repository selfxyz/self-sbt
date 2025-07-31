#!/bin/bash

# SelfPassportSBTV2 Complete Deployment Script
# This script combines TypeScript scope prediction with Foundry contract deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "🚀 SelfPassportSBTV2 Complete Deployment Pipeline"
    echo "=================================================="
    echo -e "${NC}"
}

# Check if required tools are installed
check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm first."
        exit 1
    fi
    
    if ! command -v forge &> /dev/null; then
        print_error "Foundry is not installed. Please install Foundry first."
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Validate required environment variables
validate_env_vars() {
    print_info "Validating environment variables..."
    
    local required_vars=(
        "DEPLOYER_ADDRESS"
        "IDENTITY_VERIFICATION_HUB_ADDRESS"
        "OWNER_ADDRESS"
        "VERIFICATION_CONFIG_ID"
        "SCOPE_SEED"
        "RPC_URL"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please set these environment variables and try again."
        exit 1
    fi
    
    # Set defaults for optional variables
    export VALIDITY_PERIOD=${VALIDITY_PERIOD:-15552000}  # 180 days default
    
    print_success "Environment variables validated"
}

# Install TypeScript dependencies
install_dependencies() {
    print_info "Installing TypeScript dependencies..."
    
    cd ts-scripts
    if [[ ! -f "package-lock.json" ]] || [[ "package.json" -nt "node_modules/.package-lock.json" ]]; then
        npm install
    else
        print_info "Dependencies already up to date"
    fi
    cd ..
    
    print_success "TypeScript dependencies ready"
}

# Calculate scope value using TypeScript
calculate_scope() {
    print_info "Calculating scope value using CREATE2 address prediction..."
    
    cd ts-scripts
    
    # Run the TypeScript scope calculator and capture output
    npm run calculate-scope > ../scope_output.log 2>&1
    
    # Extract the scope value from the output
    local scope_value=$(grep "Scope Value:" ../scope_output.log | cut -d' ' -f3)
    local predicted_address=$(grep "Predicted Address:" ../scope_output.log | cut -d' ' -f3)
    
    if [[ -z "$scope_value" ]]; then
        print_error "Failed to calculate scope value. Check scope_output.log for details."
        cat ../scope_output.log
        exit 1
    fi
    
    # Export the scope value for Foundry
    export SCOPE_VALUE="$scope_value"
    
    print_success "Scope value calculated: $scope_value"
    print_success "Predicted CREATE2 address: $predicted_address"
    
    cd ..
}

# Deploy contract using Foundry
deploy_contract() {
    print_info "Deploying contract with Foundry..."
    
    # Ensure we have the latest build
    forge build
    
    # Deploy the contract
    print_info "Running deployment script..."
    
    local deploy_cmd="forge script script/DeployV2.s.sol:DeployV2 --rpc-url $RPC_URL --broadcast"
    
    # Add verification if Etherscan API key is provided
    if [[ -n "$ETHERSCAN_API_KEY" ]]; then
        deploy_cmd="$deploy_cmd --verify --etherscan-api-key $ETHERSCAN_API_KEY"
        print_info "Contract verification enabled"
    fi
    
    # Execute deployment
    eval $deploy_cmd
    
    print_success "Contract deployment completed!"
}

# Save deployment information
save_deployment_info() {
    print_info "Saving deployment information..."
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local deployment_file="deployments/deployment_$(date '+%Y%m%d_%H%M%S').json"
    
    # Create deployments directory if it doesn't exist
    mkdir -p deployments
    
    # Create deployment record
    cat > "$deployment_file" << EOF
{
  "timestamp": "$timestamp",
  "network": "${NETWORK:-unknown}",
  "deployer": "$DEPLOYER_ADDRESS",
  "hub_address": "$IDENTITY_VERIFICATION_HUB_ADDRESS",
  "owner": "$OWNER_ADDRESS",
  "verification_config_id": "$VERIFICATION_CONFIG_ID",
  "validity_period": "$VALIDITY_PERIOD",
  "scope_seed": "$SCOPE_SEED",
  "scope_value": "$SCOPE_VALUE",
  "rpc_url": "$RPC_URL"
}
EOF
    
    print_success "Deployment info saved to: $deployment_file"
}

# Cleanup temporary files
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -f scope_output.log
}

# Main execution
main() {
    print_header
    
    # Trap to ensure cleanup happens
    trap cleanup EXIT
    
    check_dependencies
    validate_env_vars
    install_dependencies
    calculate_scope
    deploy_contract
    save_deployment_info
    
    print_success "🎉 Deployment pipeline completed successfully!"
    echo ""
    print_info "Deployment details:"
    echo "  • Scope Value: $SCOPE_VALUE"
    echo "  • Hub Address: $IDENTITY_VERIFICATION_HUB_ADDRESS"
    echo "  • Owner: $OWNER_ADDRESS"
    echo "  • Validity Period: $VALIDITY_PERIOD seconds"
    echo ""
    print_info "Check the Foundry output above for the deployed contract address."
}

# Show usage information
show_usage() {
    echo "SelfPassportSBTV2 Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh"
    echo ""
    echo "Required environment variables:"
    echo "  DEPLOYER_ADDRESS                     - Address that will deploy the contract"
    echo "  IDENTITY_VERIFICATION_HUB_ADDRESS   - Address of the verification hub"
    echo "  OWNER_ADDRESS                       - Contract owner address"
    echo "  VERIFICATION_CONFIG_ID              - Verification config ID (bytes32)"
    echo "  SCOPE_SEED                          - Scope seed for hashing"
    echo "  RPC_URL                             - RPC endpoint for deployment"
    echo ""
    echo "Optional environment variables:"
    echo "  VALIDITY_PERIOD                     - Token validity period (default: 15552000)"
    echo "  ETHERSCAN_API_KEY                   - For contract verification"
    echo "  NETWORK                             - Network name for records"
    echo ""
    echo "Example:"
    echo "  export DEPLOYER_ADDRESS=\"0x123...\""
    echo "  export IDENTITY_VERIFICATION_HUB_ADDRESS=\"0x456...\""
    echo "  export OWNER_ADDRESS=\"0x789...\""
    echo "  export VERIFICATION_CONFIG_ID=\"0xabcd...\""
    echo "  export SCOPE_SEED=\"production\""
    echo "  export RPC_URL=\"https://rpc.ankr.com/eth\""
    echo "  ./deploy.sh"
}

# Handle command line arguments
if [[ $# -gt 0 ]]; then
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown argument: $1"
            show_usage
            exit 1
            ;;
    esac
fi

# Run main function
main "$@"
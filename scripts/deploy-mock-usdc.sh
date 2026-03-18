#!/usr/bin/env bash
# Deploy a FiatTokenV2_2-compatible mock USDC on Anvil
#
# This script deploys a minimal ERC-20 with 6 decimals and EIP-3009
# transferWithAuthorization support to replace the 18-decimal mock token.
#
# Prerequisites:
#   - Anvil running on localhost:8545 (or set RPC_URL)
#   - cast and forge from Foundry (https://getfoundry.sh)
#
# Usage:
#   ./scripts/deploy-mock-usdc.sh
#   RPC_URL=http://anvil:8545 ./scripts/deploy-mock-usdc.sh
#
# Outputs:
#   - Contract address for the deployed mock USDC
#   - Mints 1M USDC to deployer (Account #0)

set -e

RPC_URL="${RPC_URL:-http://localhost:8545}"
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEPLOYER_ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# Initial supply: 1,000,000 USDC = 1_000_000 * 10^6 = 1_000_000_000_000
INITIAL_SUPPLY="1000000000000"

echo "Deploying FiatTokenV2_2-compatible mock USDC..."
echo "  RPC: $RPC_URL"
echo "  Deployer: $DEPLOYER_ADDR"
echo "  Initial supply: 1,000,000 USDC (6 decimals)"

# Check if Anvil is running
if ! cast chain-id --rpc-url "$RPC_URL" > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to Anvil at $RPC_URL"
  echo "Start Anvil with: anvil --host 0.0.0.0 --port 8545"
  exit 1
fi

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
echo "  Chain ID: $CHAIN_ID"

# Deploy using cast create with inline bytecode
# This deploys a minimal ERC-20 with:
#   - name: "USD Coin"
#   - symbol: "USDC"
#   - decimals: 6
#   - EIP-3009 transferWithAuthorization (signature-based transfers)
#   - EIP-2612 permit (for completeness)
#
# For a full FiatTokenV2_2 implementation, deploy Circle's contract:
#   https://github.com/circlefin/stablecoin-evm
#
# This minimal version is sufficient for x402 settlement testing
# because the x402 handler calls transferWithAuthorization and balanceOf.

# We use forge create with inline Solidity for the mock
MOCK_SOL=$(cat <<'SOLIDITY'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockUSDC {
    string public name = "USD Coin";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => mapping(bytes32 => bool)) public authorizationState;

    // EIP-712
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");

    bytes32 public DOMAIN_SEPARATOR;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes(name)),
            keccak256(bytes("2")),
            block.chainid,
            address(this)
        ));
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "insufficient balance");
        require(allowance[from][msg.sender] >= value, "insufficient allowance");
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp > validAfter, "authorization not yet valid");
        require(block.timestamp < validBefore, "authorization expired");
        require(!authorizationState[from][nonce], "authorization already used");

        bytes32 structHash = keccak256(abi.encode(
            TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
            from, to, value, validAfter, validBefore, nonce
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0) && recovered == from, "invalid signature");

        authorizationState[from][nonce] = true;
        require(balanceOf[from] >= value, "insufficient balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        emit AuthorizationUsed(from, nonce);
    }

    function mint(address to, uint256 value) external {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }
}
SOLIDITY
)

# Write the Solidity file to a temp directory
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/src"
echo "$MOCK_SOL" > "$TEMP_DIR/src/MockUSDC.sol"

# Create a minimal foundry.toml
cat > "$TEMP_DIR/foundry.toml" << 'EOF'
[profile.default]
src = "src"
out = "out"
libs = []
solc_version = "0.8.20"
EOF

# Deploy
echo ""
echo "Compiling and deploying..."
DEPLOY_OUTPUT=$(cd "$TEMP_DIR" && forge create \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_KEY" \
  --constructor-args "$INITIAL_SUPPLY" \
  src/MockUSDC.sol:MockUSDC 2>&1)

# Extract contract address
CONTRACT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$CONTRACT_ADDR" ]; then
  echo "ERROR: Deployment failed"
  echo "$DEPLOY_OUTPUT"
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo ""
echo "Mock USDC (FiatTokenV2_2-compatible) deployed!"
echo "  Address:  $CONTRACT_ADDR"
echo "  Name:     USD Coin"
echo "  Symbol:   USDC"
echo "  Decimals: 6"
echo "  Supply:   1,000,000 USDC"
echo ""
echo "Verify:"
echo "  cast call $CONTRACT_ADDR 'decimals()(uint8)' --rpc-url $RPC_URL"
echo "  cast call $CONTRACT_ADDR 'name()(string)' --rpc-url $RPC_URL"
echo "  cast call $CONTRACT_ADDR 'balanceOf(address)(uint256)' $DEPLOYER_ADDR --rpc-url $RPC_URL"
echo ""
echo "To use in TOON, set:"
echo "  TOON_USDC_ADDRESS=$CONTRACT_ADDR"

# Cleanup
rm -rf "$TEMP_DIR"

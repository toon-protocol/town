# Crosstown Token Faucet

A simple token faucet for local Crosstown development that provides both ETH and AGENT tokens.

## Features

- 🚰 **Dual Token Distribution**: Sends both ETH and AGENT tokens in a single request
- ⏱️ **Rate Limiting**: Prevents abuse with configurable time-based limits
- 🎨 **Beautiful Web UI**: Clean, modern interface for requesting tokens
- 🔍 **Auto-Discovery**: Automatically detects deployed token contract
- 📊 **Real-time Status**: Shows faucet balances and configuration

## Quick Start

The faucet is included in `docker-compose-with-local.yml`:

```bash
# Start the full stack (includes faucet)
docker compose -f docker-compose-with-local.yml up -d

# Access the faucet UI
open http://localhost:3500
```

## Configuration

Configure via environment variables:

```env
# Port (default: 3500)
PORT=3500

# RPC endpoint (default: http://anvil:8545)
RPC_URL=http://anvil:8545

# Private keys (Anvil defaults)
ETH_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
TOKEN_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Token contract address (auto-detected if not set)
TOKEN_ADDRESS=0x...

# Distribution amounts
ETH_AMOUNT=100          # ETH per request
TOKEN_AMOUNT=10000      # AGENT tokens per request

# Rate limiting
RATE_LIMIT_HOURS=1      # Hours between requests per address
```

## API Endpoints

### `GET /health`

Health check endpoint.

**Response:**

```json
{
  "status": "ok",
  "tokenAddress": "0x...",
  "tokenReady": true
}
```

### `GET /api/info`

Get faucet information.

**Response:**

```json
{
  "ethAmount": "100",
  "tokenAmount": "10000",
  "tokenSymbol": "AGENT",
  "tokenAddress": "0x...",
  "rateLimitHours": 1,
  "faucetBalances": {
    "eth": "9900.0",
    "token": "990000.0"
  },
  "ready": true
}
```

### `POST /api/request`

Request tokens for an address.

**Request:**

```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
}
```

**Success Response:**

```json
{
  "success": true,
  "transactions": {
    "eth": {
      "hash": "0x...",
      "amount": "100"
    },
    "token": {
      "hash": "0x...",
      "amount": "10000",
      "symbol": "AGENT"
    }
  }
}
```

**Error Response (Rate Limited):**

```json
{
  "error": "Rate limit exceeded",
  "message": "Please wait 45 minutes before requesting again",
  "waitMinutes": 45
}
```

## Development

Run locally for development:

```bash
cd packages/faucet

# Install dependencies
npm install

# Set environment variables
export RPC_URL=http://localhost:8545
export TOKEN_ADDRESS=0x...

# Start in development mode
npm run dev
```

## Architecture

```
┌─────────────┐
│   Web UI    │ ← User enters address
│ (index.html)│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Express    │ ← Validates address, checks rate limit
│   Server    │
└──────┬──────┘
       │
       ├─────────────────┐
       ▼                 ▼
┌─────────────┐   ┌─────────────┐
│ ETH Wallet  │   │Token Wallet │
│ (Account 1) │   │ (Account 0) │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                ▼
          ┌───────────┐
          │   Anvil   │
          │ (Local L1)│
          └───────────┘
```

## Rate Limiting

The faucet implements in-memory rate limiting based on Ethereum addresses:

- Default: 1 request per address per hour
- Limits are stored in memory (reset on container restart)
- Case-insensitive address matching

## Security Considerations

⚠️ **For local development only!**

- Private keys are hardcoded (Anvil defaults)
- No authentication required
- In-memory rate limiting (no persistence)
- Not suitable for production or public testnets

## Troubleshooting

**Faucet shows "Waiting for contract deployment":**

- The contract-deployer service hasn't completed yet
- Check logs: `docker compose logs contract-deployer`
- Wait a few seconds and refresh the page

**"Token contract not yet deployed" error:**

- Set `TOKEN_ADDRESS` environment variable manually
- Or wait for the faucet to auto-detect it

**Rate limit persists after container restart:**

- Rate limits are in-memory only and reset on restart
- Restart the faucet container: `docker compose restart faucet`

## License

MIT

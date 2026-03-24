# Overmind Registry — Spike / Proof-of-Concept

Minimal spike validating core Mina/o1js integration for the Overmind Protocol:

- **OvermindRegistry zkApp**: Executor registration (Merkle tree), VRF selection (Poseidon.hash), event emission, execution count tracking
- **RecursiveLifecycle ZkProgram**: Genesis proof + recursive step proofs composing a "verifiable biography"

## Prerequisites

- Node.js >= 20
- npm (not pnpm — this spike is self-contained)

## Setup and Run

```bash
cd packages/overmind/spike
npm install
npm test
```

### Run individual test suites

```bash
# Registry tests only (~faster, no real proofs with proofsEnabled: false)
npm run test:registry

# Recursive lifecycle tests (~slow, generates real ZK proofs)
npm run test:recursive
```

## What This Validates

| Capability | File | Status |
|---|---|---|
| Executor registration via Merkle tree | `src/OvermindRegistry.ts` | Spike |
| VRF selection via Poseidon.hash | `src/OvermindRegistry.ts` | Spike |
| Winner-selected event emission | `src/OvermindRegistry.ts` | Spike |
| Execution count tracking | `src/OvermindRegistry.ts` | Spike |
| Recursive proof composition | `src/RecursiveLifecycle.ts` | Spike |
| Genesis + N step proofs | `src/RecursiveLifecycle.ts` | Spike |

## Architecture Notes

- Uses `MerkleTree(10)` (1024 leaves) with `MerkleWitness` for the executor registry
- Off-chain registry state managed by `OffchainRegistry` helper class
- On-chain state uses 5 of 8 available Fields (fits pre-Mesa Mina limits)
- `selectExecutor()` verifies membership and emits events; full weighted selection over all executors would use a separate ZkProgram proof in production
- Recursive proofs chain a lifecycle hash: `hash(previousHash, currentCycleState)`
- Test timeout set to 10 minutes (ZK proof generation is slow)

## Proving Times

Expect roughly:
- **Compile**: 30-90 seconds per program
- **Registry methods** (proofs disabled): < 1 second each
- **Recursive genesis proof**: 30-120 seconds
- **Recursive step proof**: 30-120 seconds each

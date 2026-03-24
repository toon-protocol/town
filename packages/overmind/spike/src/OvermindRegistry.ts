/**
 * OvermindRegistry zkApp — Spike / Proof-of-Concept
 *
 * Validates core Mina integration: executor registration, VRF selection,
 * weighted random picking, and event emission using o1js.
 *
 * This is a SPIKE — minimal code to prove the research works.
 */
import {
  SmartContract,
  State,
  state,
  method,
  Field,
  Struct,
  Poseidon,
  Bool,
  MerkleTree,
  MerkleWitness,
} from 'o1js';

// --- Constants ---

/** Merkle tree height: 2^10 = 1024 leaves, more than enough for executor registry */
const REGISTRY_HEIGHT = 10;

// --- Structs ---

/**
 * An executor entry stored off-chain. The Merkle tree leaf is
 * Poseidon.hash(ExecutorEntry.toFields(entry)).
 */
export class ExecutorEntry extends Struct({
  /** x-coordinate of the executor's public key */
  pubkeyX: Field,
  /** isOdd flag of the executor's public key */
  pubkeyIsOdd: Field,
  /** Whether this executor has TEE attestation */
  hasTEE: Bool,
  /** Number of successful executions (used as weight) */
  executionCount: Field,
}) {
  hash(): Field {
    return Poseidon.hash(ExecutorEntry.toFields(this));
  }
}

/**
 * Event emitted when an executor is selected for a wake cycle.
 * PublicKey = 2 Fields, cycle = 1 Field, vrfOutput = 1 Field => 4 Fields total.
 */
export class WinnerSelectedEvent extends Struct({
  winnerX: Field,
  winnerIsOdd: Field,
  cycle: Field,
  vrfOutput: Field,
}) {}

// --- Merkle Witness ---

export class RegistryWitness extends MerkleWitness(REGISTRY_HEIGHT) {}

// --- Empty tree root (precomputed) ---

/** Root hash of an empty MerkleTree(REGISTRY_HEIGHT). Precomputed to avoid
 *  instantiating MerkleTree inside a @method (not a provable operation). */
const EMPTY_TREE_ROOT = new MerkleTree(REGISTRY_HEIGHT).getRoot();

// --- Contract ---

/**
 * OvermindRegistry zkApp.
 *
 * On-chain state uses 5 of 8 available Fields:
 *   - executorRoot: Merkle root of the executor registry
 *   - currentCycle: monotonically increasing cycle counter
 *   - winnerX: x-coordinate of last selected winner's PublicKey
 *   - winnerIsOdd: isOdd flag of last selected winner's PublicKey
 *   - vrfOutput: VRF output from most recent selection
 */
export class OvermindRegistry extends SmartContract {
  @state(Field) executorRoot = State<Field>();
  @state(Field) currentCycle = State<Field>();
  @state(Field) winnerX = State<Field>();
  @state(Field) winnerIsOdd = State<Field>();
  @state(Field) vrfOutput = State<Field>();

  events = {
    'winner-selected': WinnerSelectedEvent,
  };

  /** Initialize on-chain state. Called once during first deploy. */
  init() {
    super.init();
    this.executorRoot.set(EMPTY_TREE_ROOT);
    this.currentCycle.set(Field(0));
    this.winnerX.set(Field(0));
    this.winnerIsOdd.set(Field(0));
    this.vrfOutput.set(Field(0));
  }

  /**
   * Register a new executor in the registry.
   * Adds the executor entry at the given Merkle tree index.
   * The caller provides a witness proving the leaf is currently empty (Field(0)).
   */
  @method async registerExecutor(
    entry: ExecutorEntry,
    witness: RegistryWitness,
  ) {
    // Verify current root matches on-chain state
    const currentRoot = this.executorRoot.getAndRequireEquals();

    // Verify the leaf at this position is empty (Field(0))
    const emptyLeafRoot = witness.calculateRoot(Field(0));
    currentRoot.assertEquals(emptyLeafRoot);

    // Insert the new executor entry
    const entryHash = entry.hash();
    const newRoot = witness.calculateRoot(entryHash);

    // Update on-chain root
    this.executorRoot.set(newRoot);
  }

  /**
   * VRF-based executor selection for a wake cycle.
   *
   * For this spike, selection uses a simplified model:
   *   - vrfSeed = Poseidon.hash([cycleNumber+1, blockHash, wakeRequestHash])
   *   - The caller provides the winning executor entry + proof
   *   - The contract verifies the entry exists in the registry
   *   - Weight = (executionCount + 1) * teeMultiplier
   *   - Emits winner-selected event
   *
   * In production, weighted selection over all executors would be done
   * off-chain with a ZkProgram proof; the contract verifies the proof.
   * For this spike, we verify membership and emit the event.
   */
  @method async selectExecutor(
    blockHash: Field,
    wakeRequestHash: Field,
    winnerEntry: ExecutorEntry,
    winnerWitness: RegistryWitness,
  ) {
    // Verify registry root
    const currentRoot = this.executorRoot.getAndRequireEquals();
    const currentCycle = this.currentCycle.getAndRequireEquals();

    // Verify the winner is actually in the registry
    const entryHash = winnerEntry.hash();
    const computedRoot = winnerWitness.calculateRoot(entryHash);
    computedRoot.assertEquals(currentRoot);

    // Compute next cycle
    const nextCycle = currentCycle.add(Field(1));

    // Compute VRF seed
    const vrfSeed = Poseidon.hash([nextCycle, blockHash, wakeRequestHash]);

    // Update on-chain state
    this.currentCycle.set(nextCycle);
    this.vrfOutput.set(vrfSeed);
    this.winnerX.set(winnerEntry.pubkeyX);
    this.winnerIsOdd.set(winnerEntry.pubkeyIsOdd);

    // Emit event for Chain Bridge DVM to relay back to Nostr
    this.emitEvent('winner-selected', {
      winnerX: winnerEntry.pubkeyX,
      winnerIsOdd: winnerEntry.pubkeyIsOdd,
      cycle: nextCycle,
      vrfOutput: vrfSeed,
    });
  }

  /**
   * Record a successful execution for an executor, incrementing their
   * execution count (which increases their future VRF weight).
   *
   * The caller provides:
   *   - The current executor entry + witness (proving membership)
   *   - The updated entry with executionCount + 1
   */
  @method async recordExecution(
    currentEntry: ExecutorEntry,
    currentWitness: RegistryWitness,
    updatedEntry: ExecutorEntry,
  ) {
    // Verify registry root
    const currentRoot = this.executorRoot.getAndRequireEquals();

    // Verify the current entry is in the registry
    const currentHash = currentEntry.hash();
    const computedRoot = currentWitness.calculateRoot(currentHash);
    computedRoot.assertEquals(currentRoot);

    // Verify the updated entry has executionCount incremented by exactly 1
    updatedEntry.executionCount.assertEquals(
      currentEntry.executionCount.add(Field(1)),
    );

    // Verify all other fields are unchanged
    updatedEntry.pubkeyX.assertEquals(currentEntry.pubkeyX);
    updatedEntry.pubkeyIsOdd.assertEquals(currentEntry.pubkeyIsOdd);
    updatedEntry.hasTEE.assertEquals(currentEntry.hasTEE);

    // Compute new root with updated entry
    const updatedHash = updatedEntry.hash();
    const newRoot = currentWitness.calculateRoot(updatedHash);

    // Update on-chain root
    this.executorRoot.set(newRoot);
  }
}

// --- Utility: Off-chain registry management ---

/**
 * Helper class for managing the off-chain executor registry.
 * In production this would be persisted to IPFS/Arweave/database.
 */
export class OffchainRegistry {
  tree: MerkleTree;
  entries: Map<bigint, ExecutorEntry>;
  nextIndex: bigint;

  constructor() {
    this.tree = new MerkleTree(REGISTRY_HEIGHT);
    this.entries = new Map();
    this.nextIndex = 0n;
  }

  /** Add an executor and return the index and witness (before insertion). */
  addExecutor(entry: ExecutorEntry): {
    index: bigint;
    witness: RegistryWitness;
  } {
    const index = this.nextIndex;
    // Get witness BEFORE insertion (proves leaf is empty)
    const witness = new RegistryWitness(this.tree.getWitness(index));
    // Insert into tree
    const entryHash = entry.hash();
    this.tree.setLeaf(index, entryHash);
    this.entries.set(index, entry);
    this.nextIndex++;
    return { index, witness };
  }

  /** Get a witness for an existing executor at the given index. */
  getWitness(index: bigint): RegistryWitness {
    return new RegistryWitness(this.tree.getWitness(index));
  }

  /** Get the current Merkle root. */
  getRoot(): Field {
    return this.tree.getRoot();
  }

  /** Update an executor entry at the given index. */
  updateEntry(index: bigint, entry: ExecutorEntry): void {
    const entryHash = entry.hash();
    this.tree.setLeaf(index, entryHash);
    this.entries.set(index, entry);
  }

  /** Get the executor entry at the given index. */
  getEntry(index: bigint): ExecutorEntry | undefined {
    return this.entries.get(index);
  }
}

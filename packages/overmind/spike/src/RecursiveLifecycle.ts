/**
 * RecursiveLifecycle ZkProgram — Spike / Proof-of-Concept
 *
 * Validates that recursive proofs work in o1js: a genesis proof followed
 * by arbitrary step proofs, each verifying the previous one and chaining
 * a lifecycle hash.
 *
 * This is the "verifiable biography" primitive from the Overmind architecture.
 */
import { ZkProgram, Field, SelfProof, Struct, Poseidon } from 'o1js';

// --- Structs ---

/**
 * Public input for each lifecycle proof step.
 * Represents the state at a given cycle.
 */
export class CycleState extends Struct({
  /** Monotonically increasing cycle number (starts at 1) */
  cycleNumber: Field,
  /** Poseidon hash of agent-state.json snapshot */
  stateHash: Field,
  /** Total number of executions recorded */
  executionCount: Field,
  /** Hash of the genesis state (anchor for the chain) */
  genesisHash: Field,
}) {}

// --- ZkProgram ---

/**
 * OvermindLifecycle ZkProgram.
 *
 * - genesis(): Creates the initial proof for cycle 1.
 * - step(): Takes a SelfProof of the previous cycle, verifies it,
 *   and produces a new proof for the next cycle.
 *
 * The publicOutput is the accumulated lifecycle hash — a single Field
 * that cryptographically commits to the entire history of cycles.
 */
export const OvermindLifecycle = ZkProgram({
  name: 'OvermindLifecycle',
  publicInput: CycleState,
  publicOutput: Field,

  methods: {
    /**
     * Genesis: first cycle, no prior proof.
     * Asserts cycleNumber === 1 and produces the initial lifecycle hash.
     */
    genesis: {
      privateInputs: [],
      async method(publicInput: CycleState) {
        // First cycle must be cycle 1
        publicInput.cycleNumber.assertEquals(Field(1));

        // Genesis hash must equal the hash of this first state
        const selfHash = Poseidon.hash([
          publicInput.cycleNumber,
          publicInput.stateHash,
          publicInput.executionCount,
        ]);
        publicInput.genesisHash.assertEquals(selfHash);

        // Lifecycle hash = hash of the genesis state
        const lifecycleHash = Poseidon.hash([
          publicInput.cycleNumber,
          publicInput.stateHash,
          publicInput.executionCount,
          publicInput.genesisHash,
        ]);

        return { publicOutput: lifecycleHash };
      },
    },

    /**
     * Step: extend the lifecycle proof with a new cycle.
     * Verifies the previous proof and chains the new cycle state.
     */
    step: {
      privateInputs: [SelfProof],
      async method(
        publicInput: CycleState,
        earlierProof: SelfProof<CycleState, Field>,
      ) {
        // Verify the earlier proof is valid
        earlierProof.verify();

        // New cycle must be exactly one more than previous
        const prevCycle = earlierProof.publicInput.cycleNumber;
        publicInput.cycleNumber.assertEquals(prevCycle.add(Field(1)));

        // Genesis hash must be consistent across all steps
        publicInput.genesisHash.assertEquals(
          earlierProof.publicInput.genesisHash,
        );

        // Chain the lifecycle hash: hash(previousLifecycleHash, newCycleState)
        const previousLifecycleHash = earlierProof.publicOutput;
        const newLifecycleHash = Poseidon.hash([
          previousLifecycleHash,
          publicInput.cycleNumber,
          publicInput.stateHash,
          publicInput.executionCount,
          publicInput.genesisHash,
        ]);

        return { publicOutput: newLifecycleHash };
      },
    },
  },
});

// Export the proof class for use in tests
export const OvermindLifecycleProof = ZkProgram.Proof(OvermindLifecycle);

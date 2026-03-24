/**
 * RecursiveLifecycle ZkProgram — Spike Tests
 *
 * Creates a genesis proof, chains 3 recursive step proofs,
 * and verifies the final proof contains the correct cycle number.
 * Measures proving time for each step.
 */
import { Field, Poseidon, verify } from 'o1js';
import {
  CycleState,
  OvermindLifecycle,
} from './RecursiveLifecycle.js';

describe('RecursiveLifecycle ZkProgram', () => {
  let verificationKey: { data: string; hash: Field };

  beforeAll(async () => {
    // Compile the ZkProgram (required before proving)
    console.time('compile OvermindLifecycle');
    const compiled = await OvermindLifecycle.compile();
    verificationKey = compiled.verificationKey;
    console.timeEnd('compile OvermindLifecycle');
  });

  it('should create genesis proof and 3 recursive step proofs', async () => {
    // --- Genesis (Cycle 1) ---
    const genesisStateHash = Poseidon.hash([Field(42)]); // mock agent state
    const genesisExecCount = Field(0);

    // Compute genesis hash (used as anchor across all steps)
    const genesisHash = Poseidon.hash([
      Field(1),
      genesisStateHash,
      genesisExecCount,
    ]);

    const genesisInput = new CycleState({
      cycleNumber: Field(1),
      stateHash: genesisStateHash,
      executionCount: genesisExecCount,
      genesisHash,
    });

    console.time('prove genesis (cycle 1)');
    const genesisResult = await OvermindLifecycle.genesis(genesisInput);
    console.timeEnd('prove genesis (cycle 1)');

    const genesisProof = genesisResult.proof;
    expect(genesisProof.publicInput.cycleNumber.toString()).toBe('1');

    // Verify the genesis proof independently
    const genesisValid = await verify(genesisProof, verificationKey);
    expect(genesisValid).toBe(true);
    console.log(
      'Genesis lifecycle hash:',
      genesisProof.publicOutput.toString().slice(0, 20) + '...',
    );

    // --- Step 1 (Cycle 2) ---
    const state2Hash = Poseidon.hash([Field(100)]); // different agent state
    const step1Input = new CycleState({
      cycleNumber: Field(2),
      stateHash: state2Hash,
      executionCount: Field(1),
      genesisHash,
    });

    console.time('prove step 1 (cycle 2)');
    const step1Result = await OvermindLifecycle.step(step1Input, genesisProof);
    console.timeEnd('prove step 1 (cycle 2)');

    const step1Proof = step1Result.proof;
    expect(step1Proof.publicInput.cycleNumber.toString()).toBe('2');

    const step1Valid = await verify(step1Proof, verificationKey);
    expect(step1Valid).toBe(true);
    console.log(
      'Cycle 2 lifecycle hash:',
      step1Proof.publicOutput.toString().slice(0, 20) + '...',
    );

    // --- Step 2 (Cycle 3) ---
    const state3Hash = Poseidon.hash([Field(200)]);
    const step2Input = new CycleState({
      cycleNumber: Field(3),
      stateHash: state3Hash,
      executionCount: Field(2),
      genesisHash,
    });

    console.time('prove step 2 (cycle 3)');
    const step2Result = await OvermindLifecycle.step(step2Input, step1Proof);
    console.timeEnd('prove step 2 (cycle 3)');

    const step2Proof = step2Result.proof;
    expect(step2Proof.publicInput.cycleNumber.toString()).toBe('3');

    const step2Valid = await verify(step2Proof, verificationKey);
    expect(step2Valid).toBe(true);
    console.log(
      'Cycle 3 lifecycle hash:',
      step2Proof.publicOutput.toString().slice(0, 20) + '...',
    );

    // --- Step 3 (Cycle 4) ---
    const state4Hash = Poseidon.hash([Field(300)]);
    const step3Input = new CycleState({
      cycleNumber: Field(4),
      stateHash: state4Hash,
      executionCount: Field(3),
      genesisHash,
    });

    console.time('prove step 3 (cycle 4)');
    const step3Result = await OvermindLifecycle.step(step3Input, step2Proof);
    console.timeEnd('prove step 3 (cycle 4)');

    const step3Proof = step3Result.proof;
    expect(step3Proof.publicInput.cycleNumber.toString()).toBe('4');

    const step3Valid = await verify(step3Proof, verificationKey);
    expect(step3Valid).toBe(true);
    console.log(
      'Cycle 4 lifecycle hash:',
      step3Proof.publicOutput.toString().slice(0, 20) + '...',
    );

    // --- Verify final state ---
    // The final proof should reflect cycle 4 with 3 executions
    expect(step3Proof.publicInput.cycleNumber.toString()).toBe('4');
    expect(step3Proof.publicInput.executionCount.toString()).toBe('3');
    expect(step3Proof.publicInput.genesisHash.toString()).toBe(
      genesisHash.toString(),
    );

    // Each step should produce a different lifecycle hash
    const hashes = [
      genesisProof.publicOutput.toString(),
      step1Proof.publicOutput.toString(),
      step2Proof.publicOutput.toString(),
      step3Proof.publicOutput.toString(),
    ];
    const uniqueHashes = new Set(hashes);
    expect(uniqueHashes.size).toBe(4);

    console.log('\n--- Recursive Lifecycle Spike Results ---');
    console.log(`Total cycles proven: 4 (1 genesis + 3 steps)`);
    console.log(`All proofs verified: true`);
    console.log(`Unique lifecycle hashes: ${uniqueHashes.size}`);
    console.log(`Final proof size is constant regardless of chain length`);
  });

  it('should reject step with wrong cycle number', async () => {
    const genesisStateHash = Poseidon.hash([Field(42)]);
    const genesisHash = Poseidon.hash([
      Field(1),
      genesisStateHash,
      Field(0),
    ]);

    const genesisInput = new CycleState({
      cycleNumber: Field(1),
      stateHash: genesisStateHash,
      executionCount: Field(0),
      genesisHash,
    });

    const genesisResult = await OvermindLifecycle.genesis(genesisInput);
    const genesisProof = genesisResult.proof;

    // Try to jump to cycle 5 (should be cycle 2)
    const badInput = new CycleState({
      cycleNumber: Field(5),
      stateHash: Poseidon.hash([Field(999)]),
      executionCount: Field(1),
      genesisHash,
    });

    await expect(
      OvermindLifecycle.step(badInput, genesisProof),
    ).rejects.toThrow();
  });

  it('should reject step with mismatched genesis hash', async () => {
    const genesisStateHash = Poseidon.hash([Field(42)]);
    const genesisHash = Poseidon.hash([
      Field(1),
      genesisStateHash,
      Field(0),
    ]);

    const genesisInput = new CycleState({
      cycleNumber: Field(1),
      stateHash: genesisStateHash,
      executionCount: Field(0),
      genesisHash,
    });

    const genesisResult = await OvermindLifecycle.genesis(genesisInput);
    const genesisProof = genesisResult.proof;

    // Try step with a different genesis hash
    const badInput = new CycleState({
      cycleNumber: Field(2),
      stateHash: Poseidon.hash([Field(100)]),
      executionCount: Field(1),
      genesisHash: Field(99999), // wrong genesis hash
    });

    await expect(
      OvermindLifecycle.step(badInput, genesisProof),
    ).rejects.toThrow();
  });
});

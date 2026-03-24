/**
 * OvermindRegistry zkApp — Spike Tests
 *
 * Tests executor registration, VRF selection, event emission,
 * and execution count tracking on a local Mina blockchain.
 */
import {
  Mina,
  Field,
  Bool,
  AccountUpdate,
  PrivateKey,
  Poseidon,
} from 'o1js';
import {
  OvermindRegistry,
  ExecutorEntry,
  OffchainRegistry,
} from './OvermindRegistry.js';

describe('OvermindRegistry zkApp', () => {
  let sender: Mina.TestPublicKey;
  let zkappKey: PrivateKey;
  let zkappAddress: Mina.TestPublicKey;
  let zkapp: OvermindRegistry;
  let offchain: OffchainRegistry;

  // Executor keys
  let executor1Key: PrivateKey;
  let executor2Key: PrivateKey;
  let executor3Key: PrivateKey;

  // No compile() needed when proofsEnabled: false

  beforeEach(async () => {
    // Fresh local blockchain for each test (proofs disabled for speed)
    const Local = await Mina.LocalBlockchain({ proofsEnabled: false });
    Mina.setActiveInstance(Local);

    [sender] = Local.testAccounts;

    zkappKey = PrivateKey.random();
    zkappAddress = Mina.TestPublicKey(zkappKey);
    zkapp = new OvermindRegistry(zkappAddress);

    offchain = new OffchainRegistry();

    // Generate executor keys
    executor1Key = PrivateKey.random();
    executor2Key = PrivateKey.random();
    executor3Key = PrivateKey.random();

    // Deploy the contract (deploy() calls init() internally)
    const tx = await Mina.transaction(sender, async () => {
      AccountUpdate.fundNewAccount(sender);
      await zkapp.deploy();
    });
    await tx.prove();
    await tx.sign([sender.key, zkappKey]).send();
  });

  function makeEntry(
    key: PrivateKey,
    hasTEE: boolean,
    executionCount: number,
  ): ExecutorEntry {
    const pub = key.toPublicKey();
    const fields = pub.toFields();
    return new ExecutorEntry({
      pubkeyX: fields[0],
      pubkeyIsOdd: fields[1],
      hasTEE: Bool(hasTEE),
      executionCount: Field(executionCount),
    });
  }

  it('should deploy with correct initial state', () => {
    const cycle = zkapp.currentCycle.get();
    expect(cycle.toString()).toBe('0');

    const vrfOut = zkapp.vrfOutput.get();
    expect(vrfOut.toString()).toBe('0');

    const winX = zkapp.winnerX.get();
    expect(winX.toString()).toBe('0');
  });

  it('should register an executor and update the Merkle root', async () => {
    const entry = makeEntry(executor1Key, true, 0);
    const { witness } = offchain.addExecutor(entry);

    const tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry, witness);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // On-chain root should match off-chain root
    const onChainRoot = zkapp.executorRoot.get();
    expect(onChainRoot.toString()).toBe(offchain.getRoot().toString());
  });

  it('should register 3 executors with different weights', async () => {
    // Executor 1: TEE, 0 executions
    const entry1 = makeEntry(executor1Key, true, 0);
    const { witness: w1 } = offchain.addExecutor(entry1);
    let tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry1, w1);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Executor 2: no TEE, 5 executions (higher weight from experience)
    const entry2 = makeEntry(executor2Key, false, 5);
    const { witness: w2 } = offchain.addExecutor(entry2);
    tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry2, w2);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Executor 3: TEE, 3 executions
    const entry3 = makeEntry(executor3Key, true, 3);
    const { witness: w3 } = offchain.addExecutor(entry3);
    tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry3, w3);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Verify final root matches
    const onChainRoot = zkapp.executorRoot.get();
    expect(onChainRoot.toString()).toBe(offchain.getRoot().toString());
  });

  it('should select an executor via VRF and emit winner-selected event', async () => {
    // Register executor 1
    const entry1 = makeEntry(executor1Key, true, 0);
    const { index: idx1, witness: w1 } = offchain.addExecutor(entry1);
    let tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry1, w1);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Select executor 1 as winner (providing proof of membership)
    const blockHash = Field(12345);
    const wakeRequestHash = Field(67890);
    const memberWitness = offchain.getWitness(idx1);

    tx = await Mina.transaction(sender, async () => {
      await zkapp.selectExecutor(
        blockHash,
        wakeRequestHash,
        entry1,
        memberWitness,
      );
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Verify on-chain state updated
    const cycle = zkapp.currentCycle.get();
    expect(cycle.toString()).toBe('1');

    const storedWinnerX = zkapp.winnerX.get();
    expect(storedWinnerX.toString()).toBe(entry1.pubkeyX.toString());

    const storedVrf = zkapp.vrfOutput.get();
    // VRF should be Poseidon.hash([1, blockHash, wakeRequestHash])
    const expectedVrf = Poseidon.hash([Field(1), blockHash, wakeRequestHash]);
    expect(storedVrf.toString()).toBe(expectedVrf.toString());

    // Fetch and verify the emitted event
    const events = await zkapp.fetchEvents();
    expect(events.length).toBeGreaterThanOrEqual(1);

    const winnerEvent = events.find(
      (e) => e.type === 'winner-selected',
    );
    expect(winnerEvent).toBeDefined();
  });

  it('should record execution and increment count', async () => {
    // Register executor 1
    const entry1 = makeEntry(executor1Key, true, 0);
    const { index: idx1, witness: w1 } = offchain.addExecutor(entry1);
    let tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry1, w1);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Create updated entry with executionCount + 1
    const updatedEntry = makeEntry(executor1Key, true, 1);
    const currentWitness = offchain.getWitness(idx1);

    tx = await Mina.transaction(sender, async () => {
      await zkapp.recordExecution(entry1, currentWitness, updatedEntry);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Update offchain state to match
    offchain.updateEntry(idx1, updatedEntry);

    // Verify on-chain root matches updated off-chain tree
    const onChainRoot = zkapp.executorRoot.get();
    expect(onChainRoot.toString()).toBe(offchain.getRoot().toString());
  });

  it('should run two selection cycles showing state progression', async () => {
    // Register executor 1
    const entry1 = makeEntry(executor1Key, true, 0);
    const { index: idx1, witness: w1 } = offchain.addExecutor(entry1);
    let tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry1, w1);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // First selection
    const blockHash1 = Field(111);
    const wakeHash1 = Field(222);
    let memberWitness = offchain.getWitness(idx1);

    tx = await Mina.transaction(sender, async () => {
      await zkapp.selectExecutor(blockHash1, wakeHash1, entry1, memberWitness);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    expect(zkapp.currentCycle.get().toString()).toBe('1');
    const vrf1 = zkapp.vrfOutput.get().toString();

    // Record execution (increment count)
    const updatedEntry = makeEntry(executor1Key, true, 1);
    const execWitness = offchain.getWitness(idx1);
    tx = await Mina.transaction(sender, async () => {
      await zkapp.recordExecution(entry1, execWitness, updatedEntry);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();
    offchain.updateEntry(idx1, updatedEntry);

    // Second selection (different inputs = different VRF)
    const blockHash2 = Field(333);
    const wakeHash2 = Field(444);
    memberWitness = offchain.getWitness(idx1);

    tx = await Mina.transaction(sender, async () => {
      await zkapp.selectExecutor(
        blockHash2,
        wakeHash2,
        updatedEntry,
        memberWitness,
      );
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    expect(zkapp.currentCycle.get().toString()).toBe('2');
    const vrf2 = zkapp.vrfOutput.get().toString();

    // VRF outputs should differ (different inputs)
    expect(vrf1).not.toBe(vrf2);

    // Should have 2 winner-selected events total
    const events = await zkapp.fetchEvents();
    const winnerEvents = events.filter((e) => e.type === 'winner-selected');
    expect(winnerEvents.length).toBe(2);
  });

  it('should reject recordExecution with wrong increment', async () => {
    // Register executor
    const entry1 = makeEntry(executor1Key, true, 0);
    const { index: idx1, witness: w1 } = offchain.addExecutor(entry1);
    const tx = await Mina.transaction(sender, async () => {
      await zkapp.registerExecutor(entry1, w1);
    });
    await tx.prove();
    await tx.sign([sender.key]).send();

    // Try to increment by 2 (should fail)
    const badUpdate = makeEntry(executor1Key, true, 2);
    const witness = offchain.getWitness(idx1);

    await expect(
      Mina.transaction(sender, async () => {
        await zkapp.recordExecution(entry1, witness, badUpdate);
      }),
    ).rejects.toThrow();
  });
});

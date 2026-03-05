#!/usr/bin/env node
import { getPublicKey } from 'nostr-tools/pure';

const secretKeyHex =
  'd5c4f02f7c0f9c8e7a6b5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a';
const secretKey = Uint8Array.from(Buffer.from(secretKeyHex, 'hex'));
const pubkey = getPublicKey(secretKey);

console.log('Peer1 Secret Key:', secretKeyHex);
console.log('Peer1 Public Key:', pubkey);

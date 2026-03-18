/**
 * Mock ILP Connector
 *
 * Simulates ILP STREAM payments for local testing without real payments.
 * In a real deployment, the ILP connector would handle STREAM packet routing,
 * but for demo purposes this directly calls the BLS /handle-packet endpoint.
 */

import { encodeEventToToon } from '@toon-protocol/relay';
import type { NostrEvent } from 'nostr-tools/pure';

/**
 * Response from the Business Logic Server
 */
export interface BlsResponse {
  accept: boolean;
  fulfillment?: string;
  code?: string;
  message?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Configuration for the mock connector
 */
export interface MockConnectorConfig {
  /** BLS HTTP endpoint URL (e.g., "http://localhost:3000") */
  blsUrl: string;
  /** ILP destination address for the relay */
  destination?: string;
}

/**
 * MockIlpConnector simulates what a real ILP connector does:
 * 1. Receives a Nostr event from the agent
 * 2. TOON-encodes the event into bytes
 * 3. Makes HTTP POST to BLS /handle-packet with amount and encoded data
 * 4. Returns accept/reject result to the agent
 *
 * This allows testing the full payment flow without a real ILP network.
 */
export class MockIlpConnector {
  private readonly blsUrl: string;
  private readonly destination: string;

  constructor(config: MockConnectorConfig) {
    this.blsUrl = config.blsUrl;
    this.destination = config.destination ?? 'g.toon.demo';
  }

  /**
   * Send a payment with an embedded Nostr event to the BLS.
   *
   * @param event - The signed Nostr event to embed in the payment
   * @param amount - Payment amount in smallest units (e.g., drops)
   * @returns BLS response indicating accept/reject
   */
  async sendPayment(event: NostrEvent, amount: bigint): Promise<BlsResponse> {
    // TOON-encode the Nostr event into bytes
    const toonBytes = encodeEventToToon(event);

    // Convert to base64 for JSON transport
    const base64Data = Buffer.from(toonBytes).toString('base64');

    // Make the payment request to BLS
    const response = await fetch(`${this.blsUrl}/handle-packet`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: amount.toString(),
        destination: this.destination,
        data: base64Data,
      }),
    });

    return response.json() as Promise<BlsResponse>;
  }
}

/**
 * Helper function for simple payment sending.
 * Creates a connector instance and sends the payment in one call.
 *
 * @param blsUrl - BLS endpoint URL
 * @param event - Signed Nostr event
 * @param amount - Payment amount
 * @returns BLS response
 */
export async function sendPaymentWithEvent(
  blsUrl: string,
  event: NostrEvent,
  amount: bigint
): Promise<BlsResponse> {
  const connector = new MockIlpConnector({ blsUrl });
  return connector.sendPayment(event, amount);
}

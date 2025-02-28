import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create a new campaign",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('peer-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(100)
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
  }
});

Clarinet.test({
  name: "Can contribute to campaign",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const wallet_2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('peer-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(100)
      ], wallet_1.address),
      Tx.contractCall('peer-fund', 'contribute', [
        types.uint(1),
        types.uint(500000)
      ], wallet_2.address)
    ]);
    
    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "Can withdraw funds when goal reached",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const wallet_2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('peer-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(100)
      ], wallet_1.address),
      Tx.contractCall('peer-fund', 'contribute', [
        types.uint(1),
        types.uint(1000000)
      ], wallet_2.address),
      Tx.contractCall('peer-fund', 'withdraw-funds', [
        types.uint(1)
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 3);
    block.receipts[2].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "Can get refund when campaign fails",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const wallet_2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('peer-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(10)
      ], wallet_1.address),
      Tx.contractCall('peer-fund', 'contribute', [
        types.uint(1),
        types.uint(500000)
      ], wallet_2.address)
    ]);
    
    chain.mineEmptyBlockUntil(20);
    
    block = chain.mineBlock([
      Tx.contractCall('peer-fund', 'get-refund', [
        types.uint(1)
      ], wallet_2.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

# BuildPact Contracts

Solidity `0.8.20` contracts for the BuildPact platform, targeting **Polygon Amoy testnet** (chain ID `80002`). Native currency is **POL** (formerly MATIC — same `address(this).balance` mechanics, only the symbol changed).

---

## Contracts

### `BuildPactEscrow.sol`
Milestone-based escrow holding native POL on behalf of a client/contractor relationship, mediated by a platform oracle.

**Key features:**
- **Milestone releases** — oracle calls `releaseMilestone(id)` to transfer each tranche
- **2-hour cooling-off** — client can cancel penalty-free within the first 2 hours of contract creation
- **Graduated cancellation penalties** — see schedule below
- **Force-majeure pause** — either client or oracle can toggle a halt on all releases
- **90-day inactivity refund** — client can pull remaining balance if nothing happens for 90 days
- **2-of-3 social recovery** — three registered wallets can rotate the client address; requester and confirmer must be different wallets; 72-hour timelock enforced
- **Owner reassignment** — client can hand off to a new address at any time
- **Checks-Effects-Interactions** throughout — state flipped before every `.call{value:}`
- **Underflow-guarded cancel math** — safe at every completion percentage including 100%

### `BuildPactReputationNFT.sol`
ERC-1155 reputation badge minted by the platform oracle upon project completion.

**Key features:**
- Mintable only by `platformOracle`
- Fully on-chain metadata — `uri(tokenId)` returns a `data:application/json;base64,...` URI with embedded SVG; no IPFS dependency
- `tokenURI(uint256)` alias for ERC-721-style marketplace compatibility
- `getReputationData(tokenId)` for on-chain reads

---

## Setup

```bash
# 1. Install dependencies
npm install

# 2. Create your .env from the example
cp .env.example .env
# Edit .env — at minimum set PRIVATE_KEY

# 3. Compile (paris EVM target, no PUSH0)
npm run compile
```

---

## Deploy

```bash
# Escrow contract → Polygon Amoy
npm run deploy:amoy

# Reputation NFT → Polygon Amoy
npm run deployNFT:amoy

# Local Hardhat node (for rapid testing)
npm run deploy:local
npm run deployNFT:local
```

Both scripts read `CLIENT_ADDRESS` and `ORACLE_ADDRESS` from `.env`. If unset, the deployer address is used for both (acceptable for local testing; **use distinct addresses in production**).

After deploy, record the addresses in `.env`:
```
ESCROW_ADDRESS=0x...
NFT_ADDRESS=0x...
```

---

## Get free Amoy POL (testnet faucets)

| Faucet | URL |
|---|---|
| Polygon Faucet (official) | https://faucet.polygon.technology/ — select **Amoy** |
| Alchemy Amoy Faucet | https://www.alchemy.com/faucets/polygon-amoy |
| QuickNode Amoy Faucet | https://faucet.quicknode.com/polygon/amoy |
| Chainlink Amoy Faucet | https://faucets.chain.link/polygon-amoy |

Typical drip: **0.1–2 POL** per request — enough for many deployments.

---

## Escrow lifecycle

```
1. Deploy            → constructor sets client, oracle, milestones, coolingOffEnd
2. Fund              → client sends POL to contract address (triggers receive())
3. Oracle releases   → oracle.releaseMilestone(0) … releaseMilestone(n-1)
─────────── branching paths ───────────────────────────────────────────────────
4a. Happy path       → all milestones released, nothing more needed
4b. Client cancels   → cancelProject() — graduated penalty applied
4c. 90-day idle      → refundRemaining() pulls leftover balance to client
4d. Emergency pause  → forceMajeurePause() toggles; either client or oracle can flip
4e. Lost keys        → requestRecovery(newWallet) from one recovery wallet,
                        confirmRecovery() from a DIFFERENT recovery wallet after 72 h
4f. Transfer project → assignOwner(newClient) — instant, by current client only
```

---

## Cancellation penalty schedule

Penalties only apply **outside** the 2-hour cooling-off window.
`completionPercentage = (totalReleasedAmount × 100) / depositedAmount`

| Completion | Penalty on `depositedAmount` | + Platform fee |
|---|---|---|
| Cooling-off period (≤ 2 h from deploy) | **0%** | 0% |
| ≤ 10% | 2% | 2% of released amount |
| 11 – 40% | 5% | 2% of released amount |
| 41 – 70% | 9% | 2% of released amount |
| > 70% | 13% | 2% of released amount |

`refundAmount` to client is underflow-guarded:
```
totalDeduct  = totalReleasedAmount + penaltyAmount + platformFeeOnCompleted
refundAmount = depositedAmount > totalDeduct ? depositedAmount − totalDeduct : 0
// then capped at address(this).balance
```

---

## Social recovery

```
1. Register  →  client calls registerRecoveryWallets([w1, w2, w3])
                All 3 must be non-zero and mutually distinct.

2. Request   →  any one of {w1,w2,w3} calls requestRecovery(newWallet)
                Stores recoveryRequester = msg.sender; starts 72-hour timelock.

3. Confirm   →  a DIFFERENT recovery wallet (not recoveryRequester) calls confirmRecovery()
                after 72 hours have elapsed.
                client = pendingRecoveryWallet; all recovery state is reset.
```

---

## Minting a reputation NFT

```js
// Called from the oracle wallet after project completion:
const nft = await ethers.getContractAt("BuildPactReputationNFT", process.env.NFT_ADDRESS);

const tx = await nft.mintReputation(
  clientWalletAddress,           // to
  42,                            // projectId  (your DB primary key)
  "Kitchen Renovation",          // projectType
  5,                             // milestoneCount
  Math.floor(Date.now() / 1000)  // completionTimestamp (UNIX seconds)
);
await tx.wait();

// Retrieve full on-chain metadata URI (no IPFS call needed):
const metadataUri = await nft.uri(42);
// → "data:application/json;base64,eyJuYW1lI..."

// Same URI accessible via ERC-721-style alias for marketplace compatibility:
const same = await nft.tokenURI(42);
```

---

## Verifying on Polygonscan

```bash
# Set POLYGONSCAN_API_KEY in .env first, then:

npx hardhat verify --network amoy $ESCROW_ADDRESS \
  $CLIENT_ADDRESS $ORACLE_ADDRESS 3 \
  '["50000000000000000","50000000000000000","50000000000000000"]'

npx hardhat verify --network amoy $NFT_ADDRESS $ORACLE_ADDRESS
```

Both deploy scripts also print the exact verify command after a successful deployment.

---

## Network reference

| Property | Value |
|---|---|
| Network name | Polygon Amoy |
| Chain ID | 80002 |
| Native currency | POL |
| RPC (public) | https://rpc-amoy.polygon.technology |
| Explorer | https://amoy.polygonscan.com |
| EVM target | `paris` (no PUSH0) |
| OpenZeppelin | 5.0.2 (pinned exact, no caret) |
| Solidity | 0.8.20 |

---

## Security notes

- All state-changing functions follow **Checks-Effects-Interactions** — state is flipped before every `call{value:}`.
- Cancel math is **underflow-guarded** — safe even at 100% completion where `totalReleasedAmount ≥ depositedAmount`.
- Zero-deposit guard on completion percentage — `depositedAmount == 0` short-circuits to `0` rather than dividing by zero.
- Recovery enforces a **two-wallet confirmation** — the wallet that called `requestRecovery` cannot also call `confirmRecovery`.
- `forceMajeurePause` is a toggle accessible to both client and oracle — it can always be undone.
- `evmVersion: "paris"` in `hardhat.config.js` prevents PUSH0 being emitted, ensuring compatibility across all EVM-equivalent chains.

> **This is testnet code.** Before touching mainnet funds, commission a professional audit and write a comprehensive test suite covering every branch of `cancelProject`, the full recovery flow, force-majeure interactions, and the 90-day inactivity path.

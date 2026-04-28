// scripts/deployNFT.js
// Deploys BuildPactReputationNFT to Polygon Amoy (or local Hardhat node).
//
// Usage:
//   npx hardhat run scripts/deployNFT.js --network amoy
//   npx hardhat run scripts/deployNFT.js --network hardhat
//
// Constructor: BuildPactReputationNFT(address oracle)
//
// Override oracle via .env: ORACLE_ADDRESS

const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const net = hre.network.name;
  const balance = await hre.ethers.provider.getBalance(deployer.address);

  console.log("========================================");
  console.log("  BuildPactReputationNFT — Deployment");
  console.log("========================================");
  console.log("Network    :", net);
  console.log("Deployer   :", deployer.address);
  console.log("Balance    :", hre.ethers.formatEther(balance), "POL");
  console.log("----------------------------------------");

  if (balance === 0n) {
    console.error(
      "ERROR: Deployer has no POL.\n" +
      "Fund it from an Amoy faucet:\n" +
      "  https://faucet.polygon.technology/         (select Amoy)\n" +
      "  https://www.alchemy.com/faucets/polygon-amoy\n" +
      "  https://faucet.quicknode.com/polygon/amoy"
    );
    process.exit(1);
  }

  // ── Constructor parameter ─────────────────────────────────────────────────
  // Only the platform oracle can call mintReputation().
  // ORACLE_ADDRESS in .env overrides the deployer default.
  const oracle = process.env.ORACLE_ADDRESS || deployer.address;

  console.log("Oracle     :", oracle);
  console.log("----------------------------------------");

  const NFT = await hre.ethers.getContractFactory("BuildPactReputationNFT");
  const nft = await NFT.deploy(oracle);
  await nft.waitForDeployment();

  const address = await nft.getAddress();
  const tx = nft.deploymentTransaction();

  console.log("✓ Deployed!");
  console.log("Address    :", address);
  console.log("Tx hash    :", tx?.hash);
  console.log("========================================");

  if (net === "amoy") {
    console.log("Explorer   : https://amoy.polygonscan.com/address/" + address);
    console.log("");
    console.log("Next steps:");
    console.log("  1. Add NFT_ADDRESS=" + address + " to your .env");
    console.log("  2. After a project completes, call mintReputation() from the oracle:");
    console.log("     mintReputation(clientAddress, projectId, projectType, milestoneCount, completionTimestamp)");
    console.log("  3. Retrieve on-chain metadata: nft.uri(tokenId)");
    console.log("     → Returns a data:application/json;base64,... URI — no IPFS needed.");

    if (process.env.POLYGONSCAN_API_KEY) {
      console.log("");
      console.log("Verify on Polygonscan:");
      console.log(
        `  npx hardhat verify --network amoy ${address} ${oracle}`
      );
    } else {
      console.log("");
      console.log("Tip: set POLYGONSCAN_API_KEY in .env to enable source verification.");
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

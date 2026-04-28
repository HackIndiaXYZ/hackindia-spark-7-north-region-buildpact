// scripts/deploy.js
// Deploys BuildPactEscrow to Polygon Amoy (or local Hardhat node).
//
// Usage:
//   npx hardhat run scripts/deploy.js --network amoy
//   npx hardhat run scripts/deploy.js --network hardhat
//
// Constructor: BuildPactEscrow(address client, address oracle,
//                              uint totalMilestones, uint[] milestoneAmounts)
//
// Override client/oracle via .env: CLIENT_ADDRESS, ORACLE_ADDRESS

const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const net = hre.network.name;
  const balance = await hre.ethers.provider.getBalance(deployer.address);

  console.log("========================================");
  console.log("  BuildPactEscrow — Deployment");
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

  // ── Constructor parameters ────────────────────────────────────────────────
  // In production, client and oracle MUST be distinct addresses.
  // CLIENT_ADDRESS / ORACLE_ADDRESS in .env override the deployer default.
  const client = process.env.CLIENT_ADDRESS || deployer.address;
  const oracle = process.env.ORACLE_ADDRESS || deployer.address;

  // Three equal milestones of 0.05 POL each → total escrowed = 0.15 POL.
  // Adjust amounts and count to match your real project structure.
  const milestoneAmounts = [
    hre.ethers.parseEther("0.05"), // milestone 0
    hre.ethers.parseEther("0.05"), // milestone 1
    hre.ethers.parseEther("0.05"), // milestone 2
  ];
  const totalMilestones = milestoneAmounts.length;

  console.log("Client     :", client);
  console.log("Oracle     :", oracle);
  console.log("Milestones :", totalMilestones);
  console.log(
    "Amounts    :",
    milestoneAmounts.map((a) => hre.ethers.formatEther(a) + " POL").join(", ")
  );
  console.log("Total      :", hre.ethers.formatEther(
    milestoneAmounts.reduce((s, a) => s + a, 0n)
  ), "POL (client must send this to the contract after deploy)");
  console.log("----------------------------------------");

  const Escrow = await hre.ethers.getContractFactory("BuildPactEscrow");
  const escrow = await Escrow.deploy(
    client,
    oracle,
    totalMilestones,
    milestoneAmounts
  );
  await escrow.waitForDeployment();

  const address = await escrow.getAddress();
  const tx = escrow.deploymentTransaction();

  console.log("✓ Deployed!");
  console.log("Address    :", address);
  console.log("Tx hash    :", tx?.hash);
  console.log("========================================");

  if (net === "amoy") {
    console.log("Explorer   : https://amoy.polygonscan.com/address/" + address);
    console.log("");
    console.log("Next steps:");
    console.log("  1. Add ESCROW_ADDRESS=" + address + " to your .env");
    console.log("  2. Send", hre.ethers.formatEther(
      milestoneAmounts.reduce((s, a) => s + a, 0n)
    ), "POL to the escrow address to fund it");
    console.log("  3. Call registerRecoveryWallets([w1, w2, w3]) as the client");

    if (process.env.POLYGONSCAN_API_KEY) {
      console.log("");
      console.log("Verify on Polygonscan:");
      console.log(
        `  npx hardhat verify --network amoy ${address} ` +
        `${client} ${oracle} ${totalMilestones} ` +
        `'[${milestoneAmounts.map((a) => `"${a.toString()}"`).join(",")}]'`
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

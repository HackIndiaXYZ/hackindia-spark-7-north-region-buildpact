const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying contracts to Amoy testnet...");

  // Get the deployer's address
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log("Deploying from:", deployerAddress);

  // ─────────────────────────────────────────────
  //  Deploy BuildPactReputationNFT FIRST
  //  (we'll use it as the oracle address for escrow)
  // ─────────────────────────────────────────────

  const NFT = await ethers.getContractFactory("BuildPactReputationNFT");
  const nft = await NFT.deploy(deployerAddress);  // oracle = deployer
  await nft.waitForDeployment();
  const nftAddress = await nft.getAddress();
  console.log("BuildPactReputationNFT deployed to:", nftAddress);

  // ─────────────────────────────────────────────
  //  Deploy BuildPactEscrow
  // ─────────────────────────────────────────────

  // Sample milestone amounts (0.1, 0.2, 0.3 POL in wei)
  const milestoneAmounts = [
    ethers.parseEther("0.1"),
    ethers.parseEther("0.2"),
    ethers.parseEther("0.3")
  ];
  const totalMilestones = milestoneAmounts.length;

  const Escrow = await ethers.getContractFactory("BuildPactEscrow");
  const escrow = await Escrow.deploy(
    deployerAddress,           // _client (use deployer for testing)
    nftAddress,                // _oracle (use NFT contract address)
    totalMilestones,           // _totalMilestones (3)
    milestoneAmounts           // _milestoneAmounts array
  );
  await escrow.waitForDeployment();
  const escrowAddress = await escrow.getAddress();
  console.log("BuildPactEscrow deployed to:", escrowAddress);

  // ─────────────────────────────────────────────
  //  Summary
  // ─────────────────────────────────────────────

  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log("Escrow Address:  ", escrowAddress);
  console.log("NFT Address:     ", nftAddress);
  console.log("\nSave these addresses for Step 14-15!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
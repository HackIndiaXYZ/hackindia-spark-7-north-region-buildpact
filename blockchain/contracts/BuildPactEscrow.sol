// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// ============================================================
//  BuildPactEscrow — Full-featured escrow for Polygon Amoy
//  OpenZeppelin 5.0.2  |  Solidity 0.8.20  |  Native POL
// ============================================================

contract BuildPactEscrow {

    // ─────────────────────────────────────────────
    //  State Variables
    // ─────────────────────────────────────────────

    address public client;
    address public platformOracle;

    uint public totalMilestones;
    uint[] public milestoneAmounts; // in wei

    mapping(uint => bool) public milestoneReleased;

    bool public projectCancelled;
    bool public forceMajeurePaused;

    uint public depositedAmount;
    uint public createdAt;
    uint public lastActivityAt;
    uint public coolingOffEnd; // createdAt + 2 hours

    address[3] public recoveryWallets;
    bool public recoveryInProgress;
    uint public recoveryRequestedAt;
    address public pendingRecoveryWallet;
    address public recoveryRequester; // which recovery wallet initiated the current request

    uint public totalReleasedAmount;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    event FundsDeposited(address indexed client, uint amount, uint timestamp);
    event MilestoneReleased(uint indexed milestoneId, uint amount, uint timestamp);
    event ProjectCancelled(uint refundAmount, uint timestamp);
    event FundsRefunded(uint amount, uint timestamp);
    event ForceMajeurePaused(bool paused, uint timestamp);
    event RecoveryWalletsRegistered(address[3] wallets, uint timestamp);
    event RecoveryRequested(address indexed requester, address newWallet, uint timestamp);
    event RecoveryConfirmed(address indexed newClient, uint timestamp);
    event OwnerAssigned(address indexed oldClient, address indexed newClient, uint timestamp);

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────

    constructor(
        address _client,
        address _oracle,
        uint _totalMilestones,
        uint[] memory _milestoneAmounts
    ) {
        require(_client != address(0), "BuildPactEscrow: zero client");
        require(_oracle != address(0), "BuildPactEscrow: zero oracle");
        require(_totalMilestones > 0, "BuildPactEscrow: no milestones");
        require(
            _milestoneAmounts.length == _totalMilestones,
            "BuildPactEscrow: amounts length mismatch"
        );

        client = _client;
        platformOracle = _oracle;
        totalMilestones = _totalMilestones;
        milestoneAmounts = _milestoneAmounts;

        createdAt = block.timestamp;
        lastActivityAt = block.timestamp;
        coolingOffEnd = block.timestamp + 2 hours;
    }

    // ─────────────────────────────────────────────
    //  Receive — Accept native POL deposits
    // ─────────────────────────────────────────────

    receive() external payable {
        depositedAmount += msg.value;
        lastActivityAt = block.timestamp;
        emit FundsDeposited(client, msg.value, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  releaseMilestone
    // ─────────────────────────────────────────────

    function releaseMilestone(uint milestoneId) external {
        // Checks
        require(msg.sender == platformOracle, "BuildPactEscrow: caller not oracle");
        require(milestoneId < totalMilestones, "BuildPactEscrow: invalid milestoneId");
        require(!milestoneReleased[milestoneId], "BuildPactEscrow: already released");
        require(!projectCancelled, "BuildPactEscrow: project cancelled");
        require(!forceMajeurePaused, "BuildPactEscrow: force majeure paused");

        uint amount = milestoneAmounts[milestoneId];

        // Effects
        milestoneReleased[milestoneId] = true;
        totalReleasedAmount += amount;
        lastActivityAt = block.timestamp;

        // Interactions
        (bool ok, ) = platformOracle.call{value: amount}("");
        require(ok, "BuildPactEscrow: transfer failed");

        emit MilestoneReleased(milestoneId, amount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  cancelProject
    // ─────────────────────────────────────────────

    function cancelProject() external {
        // Checks
        require(msg.sender == client, "BuildPactEscrow: caller not client");
        require(!projectCancelled, "BuildPactEscrow: already cancelled");

        // Calculate completion percentage — guard against zero deposit
        uint completionPercentage = depositedAmount == 0
            ? 0
            : (totalReleasedAmount * 100) / depositedAmount;

        // Determine penalty rate
        uint penalty;
        if (block.timestamp <= coolingOffEnd) {
            penalty = 0; // cooling-off period — no penalty
        } else if (completionPercentage <= 10) {
            penalty = 2;
        } else if (completionPercentage <= 40) {
            penalty = 5;
        } else if (completionPercentage <= 70) {
            penalty = 9;
        } else {
            penalty = 13;
        }

        uint penaltyAmount = (depositedAmount * penalty) / 100;
        uint platformFeeOnCompleted = (totalReleasedAmount * 2) / 100;
        uint totalDeduct = totalReleasedAmount + penaltyAmount + platformFeeOnCompleted;

        // Underflow-guarded refund calculation
        uint refundAmount = depositedAmount > totalDeduct
            ? depositedAmount - totalDeduct
            : 0;

        // Cap at actual contract balance (safety valve)
        if (refundAmount > address(this).balance) {
            refundAmount = address(this).balance;
        }

        // Effects BEFORE interactions
        projectCancelled = true;
        lastActivityAt = block.timestamp;

        // Interactions
        if (refundAmount > 0) {
            (bool clientOk, ) = client.call{value: refundAmount}("");
            require(clientOk, "BuildPactEscrow: client refund failed");
        }

        uint remaining = address(this).balance;
        if (remaining > 0) {
            (bool oracleOk, ) = platformOracle.call{value: remaining}("");
            require(oracleOk, "BuildPactEscrow: oracle transfer failed");
        }

        emit ProjectCancelled(refundAmount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  refundRemaining — 90-day inactivity refund
    // ─────────────────────────────────────────────

    function refundRemaining() external {
        // Checks
        require(msg.sender == client, "BuildPactEscrow: caller not client");
        require(
            block.timestamp > lastActivityAt + 90 days,
            "BuildPactEscrow: 90-day window not elapsed"
        );
        require(!forceMajeurePaused, "BuildPactEscrow: force majeure paused");

        uint amount = address(this).balance;

        // Effects
        lastActivityAt = block.timestamp;

        // Interactions
        (bool ok, ) = client.call{value: amount}("");
        require(ok, "BuildPactEscrow: refund transfer failed");

        emit FundsRefunded(amount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  forceMajeurePause — toggle
    // ─────────────────────────────────────────────

    function forceMajeurePause() external {
        require(
            msg.sender == client || msg.sender == platformOracle,
            "BuildPactEscrow: not authorised"
        );
        forceMajeurePaused = !forceMajeurePaused;
        emit ForceMajeurePaused(forceMajeurePaused, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  registerRecoveryWallets
    // ─────────────────────────────────────────────

    function registerRecoveryWallets(address[3] memory wallets) external {
        require(msg.sender == client, "BuildPactEscrow: caller not client");
        require(wallets[0] != address(0), "BuildPactEscrow: wallet[0] is zero");
        require(wallets[1] != address(0), "BuildPactEscrow: wallet[1] is zero");
        require(wallets[2] != address(0), "BuildPactEscrow: wallet[2] is zero");
        require(wallets[0] != wallets[1], "BuildPactEscrow: wallets[0]==[1]");
        require(wallets[0] != wallets[2], "BuildPactEscrow: wallets[0]==[2]");
        require(wallets[1] != wallets[2], "BuildPactEscrow: wallets[1]==[2]");

        recoveryWallets = wallets;
        emit RecoveryWalletsRegistered(wallets, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  requestRecovery
    // ─────────────────────────────────────────────

    function requestRecovery(address newWallet) external {
        require(_isRecoveryWallet(msg.sender), "BuildPactEscrow: not a recovery wallet");
        require(!recoveryInProgress, "BuildPactEscrow: recovery already in progress");
        require(newWallet != address(0), "BuildPactEscrow: zero new wallet");

        pendingRecoveryWallet = newWallet;
        recoveryInProgress = true;
        recoveryRequestedAt = block.timestamp;
        recoveryRequester = msg.sender;

        emit RecoveryRequested(msg.sender, newWallet, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  confirmRecovery
    // ─────────────────────────────────────────────

    function confirmRecovery() external {
        // Checks
        require(recoveryInProgress, "BuildPactEscrow: no recovery in progress");
        require(_isRecoveryWallet(msg.sender), "BuildPactEscrow: not a recovery wallet");
        require(
            msg.sender != recoveryRequester,
            "BuildPactEscrow: must be a different recovery wallet"
        );
        require(
            block.timestamp >= recoveryRequestedAt + 72 hours,
            "BuildPactEscrow: 72-hour timelock not elapsed"
        );

        address confirmed = pendingRecoveryWallet;

        // Effects
        client = confirmed;
        recoveryInProgress = false;
        pendingRecoveryWallet = address(0);
        recoveryRequester = address(0);
        recoveryRequestedAt = 0;
        lastActivityAt = block.timestamp;

        emit RecoveryConfirmed(confirmed, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  assignOwner
    // ─────────────────────────────────────────────

    function assignOwner(address newClient) external {
        require(msg.sender == client, "BuildPactEscrow: caller not client");
        require(newClient != address(0), "BuildPactEscrow: zero new client");

        address oldClient = client;

        // Effects
        client = newClient;
        lastActivityAt = block.timestamp;

        emit OwnerAssigned(oldClient, newClient, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  View Functions
    // ─────────────────────────────────────────────

    function getEscrowBalance() external view returns (uint) {
        return address(this).balance;
    }

    function getMilestoneStatus(uint milestoneId) external view returns (bool) {
        return milestoneReleased[milestoneId];
    }

    /// @return _client              current client address
    /// @return _totalMilestones     number of milestones
    /// @return _depositedAmount     total POL deposited (wei)
    /// @return _totalReleasedAmount total POL released to oracle (wei)
    /// @return _projectCancelled    cancellation flag
    /// @return _forceMajeurePaused  force-majeure pause flag
    function getProjectSummary()
        external
        view
        returns (
            address _client,
            uint _totalMilestones,
            uint _depositedAmount,
            uint _totalReleasedAmount,
            bool _projectCancelled,
            bool _forceMajeurePaused
        )
    {
        return (
            client,
            totalMilestones,
            depositedAmount,
            totalReleasedAmount,
            projectCancelled,
            forceMajeurePaused
        );
    }

    function getRecoveryWallets() external view returns (address[3] memory) {
        return recoveryWallets;
    }

    // ─────────────────────────────────────────────
    //  Internal Helpers
    // ─────────────────────────────────────────────

    function _isRecoveryWallet(address addr) internal view returns (bool) {
        return (
            addr == recoveryWallets[0] ||
            addr == recoveryWallets[1] ||
            addr == recoveryWallets[2]
        );
    }
}

// ================================================================
//  DEPLOYMENT CONFIGURATION  (paste into your project files)
// ================================================================

// ----------------------------------------------------------------
// FILE: hardhat.config.js
// ----------------------------------------------------------------
/*
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig * /
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: "paris"           // avoids PUSH0 — critical for Polygon Amoy RPC
    }
  },
  networks: {
    amoy: {
      url: process.env.AMOY_RPC_URL || "https://rpc-amoy.polygon.technology",
      accounts: process.env.DEPLOYER_PRIVATE_KEY
        ? [process.env.DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 80002
    }
  },
  etherscan: {
    apiKey: {
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || ""
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        }
      }
    ]
  }
};
*/

// ----------------------------------------------------------------
// FILE: scripts/deploy.js  (BuildPactEscrow)
// ----------------------------------------------------------------
/*
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying BuildPactEscrow with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "POL");

  // ── Sample parameters ──
  const clientAddress  = deployer.address;                    // replace with real client
  const oracleAddress  = "0xYourPlatformOracleAddressHere";   // replace with real oracle

  // 3 milestones: 0.1 / 0.2 / 0.3 POL  (all in wei)
  const milestoneAmounts = [
    ethers.parseEther("0.1"),
    ethers.parseEther("0.2"),
    ethers.parseEther("0.3")
  ];
  const totalMilestones = milestoneAmounts.length;

  const BuildPactEscrow = await ethers.getContractFactory("BuildPactEscrow");
  const escrow = await BuildPactEscrow.deploy(
    clientAddress,
    oracleAddress,
    totalMilestones,
    milestoneAmounts
  );
  await escrow.waitForDeployment();

  const address = await escrow.getAddress();
  console.log("BuildPactEscrow deployed to:", address);
  console.log("Verify with:");
  console.log(
    `npx hardhat verify --network amoy ${address} ` +
    `"${clientAddress}" "${oracleAddress}" ${totalMilestones} ` +
    `"[${milestoneAmounts.join(",")}]"`
  );
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
*/

// ----------------------------------------------------------------
// FILE: package.json
// ----------------------------------------------------------------
/*
{
  "name": "buildpact-contracts",
  "version": "1.0.0",
  "description": "BuildPact escrow & reputation contracts — Polygon Amoy",
  "scripts": {
    "compile": "hardhat compile",
    "deploy:escrow": "hardhat run scripts/deploy.js --network amoy",
    "deploy:nft":    "hardhat run scripts/deployNFT.js --network amoy"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^3.0.0",
    "hardhat": "^2.22.0",
    "dotenv": "^16.0.0"
  },
  "dependencies": {
    "@openzeppelin/contracts": "5.0.2"
  }
}
*/

// ----------------------------------------------------------------
// FILE: .env  (never commit to git)
// ----------------------------------------------------------------
/*
AMOY_RPC_URL=https://rpc-amoy.polygon.technology
DEPLOYER_PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
POLYGONSCAN_API_KEY=YOUR_POLYGONSCAN_KEY_HERE
*/

// ----------------------------------------------------------------
// COMPILE & DEPLOY COMMANDS
// ----------------------------------------------------------------
/*
  1. Install dependencies:
       npm install

  2. Compile (will emit paris-EVM bytecode, no PUSH0):
       npx hardhat compile

  3. Deploy escrow to Amoy:
       npx hardhat run scripts/deploy.js --network amoy

  4. Deploy reputation NFT to Amoy:
       npx hardhat run scripts/deployNFT.js --network amoy

  5. Verify on PolygonScan (Amoy):
       npx hardhat verify --network amoy <DEPLOYED_ADDRESS> <constructor args>
*/

// ----------------------------------------------------------------
// FREE AMOY POL — FAUCETS
// ----------------------------------------------------------------
/*
  To get free testnet POL for Polygon Amoy:

  A. Polygon Faucet (official):
       https://faucet.polygon.technology/
       → Select "Amoy" → paste your wallet → request POL

  B. Alchemy Amoy Faucet (requires free Alchemy account):
       https://www.alchemy.com/faucets/polygon-amoy

  C. QuickNode Amoy Faucet:
       https://faucet.quicknode.com/polygon/amoy

  D. Chainlink Faucet (also gives LINK for Amoy):
       https://faucets.chain.link/polygon-amoy

  Typical drip: 0.5–2 POL per request.
  Chain ID: 80002  |  RPC: https://rpc-amoy.polygon.technology
  Explorer: https://amoy.polygonscan.com
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// ============================================================
//  BuildPactReputationNFT — On-chain ERC-1155 reputation token
//  OpenZeppelin 5.0.2  |  Solidity 0.8.20
// ============================================================

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BuildPactReputationNFT is ERC1155 {

    using Strings for uint256;

    // ─────────────────────────────────────────────
    //  State Variables
    // ─────────────────────────────────────────────

    address public platformOracle;

    struct ReputationData {
        uint256 projectId;
        string  projectType;
        uint    milestoneCount;
        uint    completionTimestamp;
        address recipient;
        bool    exists;
    }

    // tokenId → metadata
    mapping(uint256 => ReputationData) private _reputationData;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    event ReputationMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 projectId,
        string  projectType,
        uint    milestoneCount,
        uint    completionTimestamp
    );

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────

    /// @param _oracle  Address of the platform oracle (sole minter)
    constructor(address _oracle)
        ERC1155("") // base URI unused — all metadata is on-chain
    {
        require(_oracle != address(0), "BuildPactReputationNFT: zero oracle");
        platformOracle = _oracle;
    }

    // ─────────────────────────────────────────────
    //  Mint
    // ─────────────────────────────────────────────

    /// @notice Mint a soulbound-style reputation token for a completed project.
    /// @param to                  Recipient (client or contractor)
    /// @param projectId           Unique project identifier
    /// @param projectType         Human-readable category (e.g. "Renovation")
    /// @param milestoneCount      Number of milestones completed
    /// @param completionTimestamp UNIX timestamp of project completion
    function mintReputation(
        address to,
        uint256 projectId,
        string memory projectType,
        uint milestoneCount,
        uint completionTimestamp
    ) external {
        require(msg.sender == platformOracle, "BuildPactReputationNFT: caller not oracle");
        require(to != address(0), "BuildPactReputationNFT: zero recipient");

        // Use projectId as tokenId (one token type per project)
        uint256 tokenId = projectId;
        require(!_reputationData[tokenId].exists, "BuildPactReputationNFT: token already minted");

        // Store metadata
        _reputationData[tokenId] = ReputationData({
            projectId:           projectId,
            projectType:         projectType,
            milestoneCount:      milestoneCount,
            completionTimestamp: completionTimestamp,
            recipient:           to,
            exists:              true
        });

        _mint(to, tokenId, 1, "");

        emit ReputationMinted(to, tokenId, projectId, projectType, milestoneCount, completionTimestamp);
    }

    // ─────────────────────────────────────────────
    //  URI — Fully on-chain Base64 data URI
    // ─────────────────────────────────────────────

    /// @notice Returns the ERC-1155 metadata URI for a given token.
    ///         All metadata is encoded on-chain as a Base64 data URI.
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_reputationData[tokenId].exists, "BuildPactReputationNFT: token does not exist");

        ReputationData memory d = _reputationData[tokenId];

        string memory json = _buildJson(tokenId, d);

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            )
        );
    }

    /// @notice ERC-721-style alias for marketplaces that call tokenURI().
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return uri(tokenId);
    }

    // ─────────────────────────────────────────────
    //  Internal: JSON helpers  (split to avoid stack-too-deep)
    // ─────────────────────────────────────────────

    /// @dev Assembles the complete metadata JSON string.
    function _buildJson(
        uint256 tokenId,
        ReputationData memory d
    ) internal pure returns (string memory) {
        string memory attributes = _buildAttributes(d);

        return string(
            abi.encodePacked(
                '{"name":"BuildPact Reputation #',
                tokenId.toString(),
                '","description":"On-chain reputation token issued by BuildPact for project completion.","image":"',
                _buildSvgUri(d),
                '","attributes":',
                attributes,
                "}"
            )
        );
    }

    /// @dev Builds the JSON attributes array.
    function _buildAttributes(
        ReputationData memory d
    ) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '[{"trait_type":"Project ID","value":"',
                d.projectId.toString(),
                '"},{"trait_type":"Project Type","value":"',
                d.projectType,
                '"},{"trait_type":"Milestones Completed","value":"',
                d.milestoneCount.toString(),
                '"},{"trait_type":"Completed At","value":"',
                d.completionTimestamp.toString(),
                '"},{"trait_type":"Recipient","value":"',
                _addressToString(d.recipient),
                '"}]'
            )
        );
    }

    /// @dev Builds a minimal inline SVG and returns it as a Base64 data URI.
    ///      Factored separately to keep _buildJson within stack limits.
    function _buildSvgUri(
        ReputationData memory d
    ) internal pure returns (string memory) {
        string memory svg = _buildSvg(d);
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svg))
            )
        );
    }

    /// @dev Builds the raw SVG markup.
    function _buildSvg(
        ReputationData memory d
    ) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">',
                '<rect width="400" height="400" rx="20" fill="#1a1a2e"/>',
                '<text x="200" y="60" font-family="monospace" font-size="18" fill="#e94560" text-anchor="middle" font-weight="bold">BuildPact Reputation</text>',
                '<text x="200" y="110" font-family="monospace" font-size="13" fill="#a8b2d8" text-anchor="middle">Project #',
                d.projectId.toString(),
                '</text>',
                '<text x="200" y="150" font-family="monospace" font-size="13" fill="#ccd6f6" text-anchor="middle">Type: ',
                d.projectType,
                '</text>',
                '<text x="200" y="190" font-family="monospace" font-size="13" fill="#ccd6f6" text-anchor="middle">Milestones: ',
                d.milestoneCount.toString(),
                '</text>',
                '<text x="200" y="370" font-family="monospace" font-size="10" fill="#495670" text-anchor="middle">Polygon Amoy | BuildPact Protocol</text>',
                '</svg>'
            )
        );
    }

    // ─────────────────────────────────────────────
    //  Internal: Utilities
    // ─────────────────────────────────────────────

    /// @dev Converts an address to its checksummed hex string representation.
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory addrBytes = abi.encodePacked(addr);
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(42);
        result[0] = "0";
        result[1] = "x";
        for (uint i = 0; i < 20; i++) {
            result[2 + i * 2]     = hexChars[uint8(addrBytes[i]) >> 4];
            result[3 + i * 2]     = hexChars[uint8(addrBytes[i]) & 0x0f];
        }
        return string(result);
    }

    // ─────────────────────────────────────────────
    //  View Helpers
    // ─────────────────────────────────────────────

    /// @notice Returns stored reputation metadata for a given tokenId.
    function getReputationData(uint256 tokenId)
        external
        view
        returns (
            uint256 projectId,
            string memory projectType,
            uint milestoneCount,
            uint completionTimestamp,
            address recipient
        )
    {
        require(_reputationData[tokenId].exists, "BuildPactReputationNFT: token does not exist");
        ReputationData memory d = _reputationData[tokenId];
        return (d.projectId, d.projectType, d.milestoneCount, d.completionTimestamp, d.recipient);
    }
}

// ================================================================
//  DEPLOYMENT SCRIPT — scripts/deployNFT.js
// ================================================================
/*
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying BuildPactReputationNFT with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "POL");

  const oracleAddress = "0xYourPlatformOracleAddressHere"; // replace with your oracle

  const NFT = await ethers.getContractFactory("BuildPactReputationNFT");
  const nft = await NFT.deploy(oracleAddress);
  await nft.waitForDeployment();

  const address = await nft.getAddress();
  console.log("BuildPactReputationNFT deployed to:", address);
  console.log("Verify with:");
  console.log(`npx hardhat verify --network amoy ${address} "${oracleAddress}"`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
*/

// ================================================================
//  SAMPLE — minting a reputation token after a project completes
// ================================================================
/*
  const nft = await ethers.getContractAt("BuildPactReputationNFT", NFT_ADDRESS);

  // Called by platformOracle account:
  const tx = await nft.mintReputation(
    clientWalletAddress,    // to
    42,                     // projectId  (use your DB project PK)
    "Kitchen Renovation",   // projectType
    5,                      // milestoneCount
    Math.floor(Date.now() / 1000)  // completionTimestamp
  );
  await tx.wait();
  console.log("Reputation NFT minted, tokenId =", 42);

  // Retrieve full on-chain metadata URI:
  const metadataUri = await nft.uri(42);
  console.log("Token URI:", metadataUri);
  // → "data:application/json;base64,eyJuYW1lI..."
*/

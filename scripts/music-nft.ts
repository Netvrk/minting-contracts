// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, upgrades } from "hardhat";

async function main() {
  const nftAddress = "0x8aedef6f376078ad4ec9815820c3c887d99e9dbc";
  const treasury = "0xaC82A4531bC5C764cb6CE7320B3F38547c6F97cF";
  // We get the contract to deploy
  const MusicNFT = await ethers.getContractFactory("MusicNFT");
  const musicNft = await upgrades.deployProxy(MusicNFT, [
    "MUSIC",
    "MUSIC",
    "https://api.example.com/",
    treasury,
    nftAddress,
  ]);

  await musicNft.deployed();

  console.log("MusicNFT deployed to:", musicNft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

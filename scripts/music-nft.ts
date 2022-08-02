// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, upgrades } from "hardhat";

async function main() {
  const nftAddress = "0x44DfAb13eC65288B808A1D09D7Fe30862f18A803";
  const treasury = "0x88d87c6fEFEAEA269823699e0d4F6900B2F2A9E8";
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

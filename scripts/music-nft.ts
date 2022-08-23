// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, upgrades } from "hardhat";

async function main() {
  const nftAddress = "0xe88A781C82d3Eb8b1C1A98C270f2826B8bcc5DBb";
  const treasury = "0xC88E18F8bc3f6F4CbA55e14439780563039ED4d5";
  const manager = "0x08c3405ba60f9263Ec18d20959D1c39F9dff4b4b";
  // We get the contract to deploy
  const MusicNFT = await ethers.getContractFactory("MusicNFT");
  const musicNft = await upgrades.deployProxy(MusicNFT, [
    "MUSIC",
    "MUSIC",
    "https://api.netvrk.co/api/damon-dash/",
    treasury,
    nftAddress,
    manager,
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

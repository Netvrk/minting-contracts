// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, upgrades } from "hardhat";

async function main() {
  // We get the contract to deploy
  const MusicNFT = await ethers.getContractFactory("MusicNFT");
  const musicNft = await upgrades.deployProxy(MusicNFT, [
    "DROP",
    "DROP",
    "0x486FCe87b3aF20696d9Acc87A1614cC743180986",
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

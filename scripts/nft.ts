// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, upgrades } from "hardhat";

async function main() {
  // We get the contract to deploy
  const NFT = await ethers.getContractFactory("NFT");
  const nft = await upgrades.deployProxy(
    NFT,
    ["AVTR", "AVTR", "https://api.netvrk.co/api/damon-dash/avatar/"],
    {
      kind: "uups",
    }
  );

  await nft.deployed();

  console.log("NFT deployed to:", nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

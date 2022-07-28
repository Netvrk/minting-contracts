// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const Splittter = await ethers.getContractFactory("PaymentSplitter");
  const splitter = await Splittter.deploy(
    [
      "0xF3d66FFc6E51db57A4d8231020F373A14190567F",
      "0x08c3405ba60f9263Ec18d20959D1c39F9dff4b4b",
    ],
    ["70", "30"]
  );

  await splitter.deployed();

  console.log("Splitter deployed to:", splitter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

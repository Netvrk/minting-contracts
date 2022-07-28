import hre from "hardhat";

async function main() {
  await hre.run("verify:verify", {
    address: "0x37BA1B843939Cd3D3EF33245A299F92ce3297Bd1",
    constructorArguments: [
      [
        "0xF3d66FFc6E51db57A4d8231020F373A14190567F",
        "0x08c3405ba60f9263Ec18d20959D1c39F9dff4b4b",
      ],
      ["70", "30"],
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

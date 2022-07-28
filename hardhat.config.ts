import * as dotenv from "dotenv";

import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";
dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.15",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY_1 !== undefined &&
        process.env.PRIVATE_KEY_2 !== undefined
          ? [process.env.PRIVATE_KEY_1, process.env.PRIVATE_KEY_2]
          : [],
    },
    rinkeby: {
      url: process.env.RINKEBY_URL || "",
      accounts:
        process.env.PRIVATE_KEY_1 !== undefined &&
        process.env.PRIVATE_KEY_2 !== undefined
          ? [process.env.PRIVATE_KEY_1, process.env.PRIVATE_KEY_2]
          : [],
    },
    matic: {
      chainId: 137,
      url: process.env.MATIC_URL || "",
      accounts:
        process.env.PRIVATE_KEY_1 !== undefined &&
        process.env.PRIVATE_KEY_2 !== undefined
          ? [process.env.PRIVATE_KEY_1, process.env.PRIVATE_KEY_2]
          : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;

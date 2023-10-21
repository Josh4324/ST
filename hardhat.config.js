require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: ".env" });

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const PRIVATE_API_KEY_URL = process.env.PRIVATE_API_KEY_URL;
const ALCHEMY_API_KEY_URL = process.env.ALCHEMY_API_KEY_URL;
const ROPSTEN_PRIVATE_KEY = process.env.ROPSTEN_PRIVATE_KEY;
const GOERLI_API_KEY_URL = process.env.GOERLI_API_KEY_URL;
const GOERLI_PRIVATE_KEY = process.env.GOERLI_PRIVATE_KEY;
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY;
const MUMBAI_API_KEY = process.env.MUMBAI_API_KEY;
const MUMBAI_API_KEY_URL = process.env.MUMBAI_API_KEY_URL;
const MUMBAI_PRIVATE_KEY = process.env.MUMBAI_PRIVATE_KEY;
const SWISS_URL = process.env.SWISS_URL;
const BSCSCAN = process.env.BSCSCAN;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  networks: {
    bsc: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: [MUMBAI_PRIVATE_KEY],
    },
    rinkeby: {
      url: PRIVATE_API_KEY_URL,
      accounts: [PRIVATE_KEY],
    },
    ropsten: {
      url: ALCHEMY_API_KEY_URL,
      accounts: [ROPSTEN_PRIVATE_KEY],
    },
    goerli: {
      url: GOERLI_API_KEY_URL,
      accounts: [GOERLI_PRIVATE_KEY],
    },
    avax: {
      url: "https://avalanche-fuji-c-chain.publicnode.com",
      chainId: 43113,
      accounts: [MUMBAI_PRIVATE_KEY],
    },
    mumbai: {
      url: MUMBAI_API_KEY_URL,
      accounts: [MUMBAI_PRIVATE_KEY],
    },
    swiss: {
      url: SWISS_URL,
      accounts: [MUMBAI_PRIVATE_KEY],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    //apiKey: BSCSCAN,
    //apiKey: ETHERSCAN,
    //apiKey: MUMBAI_API_KEY,
    apiKey: {
      avalancheFujiTestnet: "9VYT6UA2RWD6AB71JI3P4SWGV3DKXB3J6Y",
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
  mocha: {
    timeout: 10000000000,
  },
};

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const st = await hre.ethers.deployContract("ST2", [
    "0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2",
    "0xBF62ef1486468a6bd26Dd669C06db43dEd5B849B",
    "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6",
  ]);

  await st.waitForDeployment();

  console.log(`Contract deployed to ${st.target}`);

  console.log("Sleeping.....");
  // Wait for etherscan to notice that the contract has been deployed
  await sleep(30000);

  // Verify the contract after deploying
  await hre.run("verify:verify", {
    address: st.target,
    constructorArguments: [
      "0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2",
      "0xBF62ef1486468a6bd26Dd669C06db43dEd5B849B",
      "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6",
    ],
    contract: "contracts/OrderInterChain.sol:ST2",
  });

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const st = await hre.ethers.deployContract("ST1", [
    "0x96bb60aAAec09A0FceB4527b81bbF3Cc0c171393",
  ]);

  await st.waitForDeployment();

  console.log(`Contract deployed to ${st.target}`);

  console.log("Sleeping.....");
  // Wait for etherscan to notice that the contract has been deployed
  await sleep(30000);

  // Verify the contract after deploying
  await hre.run("verify:verify", {
    address: st.target,
    constructorArguments: ["0x96bb60aAAec09A0FceB4527b81bbF3Cc0c171393"],
    contract: "contracts/OrderNative.sol:ST1",
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

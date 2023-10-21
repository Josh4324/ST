// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const st = await hre.ethers.deployContract("ST2", [
    "0x819B58A646CDd8289275A87653a2aA4902b14fe6",
    "0xC249632c2D40b9001FE907806902f63038B737Ab",
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
      "0x819B58A646CDd8289275A87653a2aA4902b14fe6",
      "0xC249632c2D40b9001FE907806902f63038B737Ab",
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

const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ST", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, user1, user2, user3, user4, user5] =
      await ethers.getSigners();

    const ST = await ethers.getContractFactory("ST");
    const st = await ST.deploy();

    return { st, owner, user1, user2, user3, user4, user5 };
  }

  describe("ST", function () {
    it("Test 1", async function () {
      const { st, user1 } = await loadFixture(deploy);
      const dofp = Math.floor(new Date("2023-10-15").getTime() / 1000);
      const dolp = Math.floor(new Date("2023-10-30").getTime() / 1000);

      await st.createOrder("ST", 20, dofp, dolp, 1, user1.address, {
        value: ethers.parseEther("20"),
      });

      console.log(st.target);

      console.log(await ethers.provider.getBalance(st.target));
    });
  });
});

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
    const st = await ST.deploy(owner.address, owner.address, owner.address);

    return { st, owner, user1, user2, user3, user4, user5 };
  }

  describe("ST", function () {
    it("Test 1", async function () {
      const { st, user1 } = await loadFixture(deploy);
      const t1 = 1 * 24 * 60 * 60;
      const t2 = 10 * 24 * 60 * 60;

      const t3 = 1;
      const t4 = 10 * 24 * 60 * 60;

      function sleep(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
      }

      await st.createOrder(
        "Or2",
        ethers.parseEther("20"),
        ethers.parseEther("10"),
        t3,
        t4,
        20,
        user1.address,
        {
          value: ethers.parseEther("20"),
        }
      );

      await st.createOrder(
        "Or1",
        ethers.parseEther("20"),
        ethers.parseEther("20"),
        t1,
        t2,
        60,
        user1.address,
        {
          value: ethers.parseEther("20"),
        }
      );

      await st.createOrderInterChain(
        ["name", "destinationChain", "destinationAddress", "symbol"],
        [ethers.parseEther("20"), ethers.parseEther("5"), t1, t2, 60],
        user1.address,
        {
          value: ethers.parseEther("20"),
        }
      );

      console.log(await ethers.provider.getBalance(st.target));
      //await st.deleteOrder(0);
      await st.connect(user1).payOrder();
      await st.editOrder(0, ethers.parseEther("5"), t4, 20);

      //console.log(await st.getOrder(0));
      await sleep(70000);

      await st.payOrder();

      console.log(await st.payList2());

      await st.withdraw();

      //console.log(st.target);
      console.log(await ethers.provider.getBalance(st.target));
    });
  });
});

const chai = require("chai");
const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);
const { expect } = chai;

describe("TokenMaster", function () {
  let TokenMaster, tokenMaster, owner, user1, user2;

  beforeEach(async () => {
    [owner, user1, user2] = await ethers.getSigners();
    TokenMaster = await ethers.getContractFactory("TokenMaster");
    tokenMaster = await TokenMaster.deploy("TokenMaster", "TM");
    await tokenMaster.deployed();
  });

  describe("Initialization", function () {
    it("Should set the name and symbol correctly", async () => {
      expect(await tokenMaster.name()).to.equal("TokenMaster");
      expect(await tokenMaster.symbol()).to.equal("TM");
    });
  });

  describe("Occasion Management", function () {
    it("Should create a new occasion", async () => {
      await tokenMaster.connect(owner).createOccasion(
        ethers.utils.parseEther("1"),
        100
      );

      const [id, cost, totalSeats, seatsTaken] = await tokenMaster.getOccasionById(1);
      expect(id.toNumber()).to.equal(1);
      expect(cost.toString()).to.equal(ethers.utils.parseEther("1").toString());
      expect(totalSeats.toNumber()).to.equal(100);
      expect(seatsTaken.toNumber()).to.equal(0);
    });

    it("Should return all occasion details", async () => {
      await tokenMaster.createOccasion(ethers.utils.parseEther("1000"), 10);
      await tokenMaster.createOccasion(ethers.utils.parseEther("2000"), 20);

      const [ids, costs, totalSeatsList, seatsTakenList] = await tokenMaster.getAllOccasions();

      expect(ids.length).to.equal(2);
      expect(costs[0].toString()).to.equal(ethers.utils.parseEther("1000").toString());
      expect(totalSeatsList[1].toNumber()).to.equal(20);
    });
  });

  describe("Ticket Purchase", function () {
    it("Should allow user to buy tickets and track seats", async () => {
      await tokenMaster.createOccasion(ethers.utils.parseEther("1"), 10);

      await tokenMaster.connect(user1).buyTickets(1, 2, {
        value: ethers.utils.parseEther("2")
      });

      const balance = await tokenMaster.balanceOf(user1.address);
      expect(balance.toNumber()).to.equal(2);

      const seats = await tokenMaster.getSeatsTaken(1);
      expect(seats.length).to.equal(2);
      expect(seats[0]).to.equal(user1.address);
      expect(seats[1]).to.equal(user1.address);
    });
  });

  describe("Ticket Resale", function () {
    it("Should enforce resale price cap (1.5x original)", async () => {
      await tokenMaster.createOccasion(ethers.utils.parseEther("1"), 1);

      await tokenMaster.connect(user1).buyTickets(1, 1, {
        value: ethers.utils.parseEther("1")
      });

      await tokenMaster.connect(user1).listTicketForResale(1, ethers.utils.parseEther("1.5"));

      const listing = await tokenMaster.resaleListings(1);
      expect(listing.price.toString()).to.equal(ethers.utils.parseEther("1.5").toString());
      expect(listing.seller).to.equal(user1.address);

      await expect(
        tokenMaster.connect(user1).listTicketForResale(1, ethers.utils.parseEther("2"))
      ).to.be.revertedWith("Price exceeds 1.5x original");
    });

    it("Should allow resale purchase and transfer token", async () => {
      await tokenMaster.createOccasion(ethers.utils.parseEther("1"), 1);

      await tokenMaster.connect(user1).buyTickets(1, 1, {
        value: ethers.utils.parseEther("1")
      });

      await tokenMaster.connect(user1).listTicketForResale(1, ethers.utils.parseEther("1"));

      await tokenMaster.connect(user2).buyResaleTicket(1, {
        value: ethers.utils.parseEther("1")
      });

      expect(await tokenMaster.ownerOf(1)).to.equal(user2.address);
    });
  });

  describe("Refund and Withdrawal", function () {
    it("Should cancel ticket and refund 90%", async () => {
      await tokenMaster.createOccasion(ethers.utils.parseEther("1"), 1);

      await tokenMaster.connect(user1).buyTickets(1, 1, {
        value: ethers.utils.parseEther("1")
      });

      const before = await ethers.provider.getBalance(user1.address);

      const tx = await tokenMaster.connect(user1).cancelAndRefundTicket(1);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      const after = await ethers.provider.getBalance(user1.address);
      const actualRefund = after.add(gasUsed).sub(before);
      const expectedRefund = ethers.utils.parseEther("0.9");

      const diff = actualRefund.sub(expectedRefund).abs();
      expect(diff.lte(ethers.utils.parseEther("0.01"))).to.be.true;
    });

    it("Should withdraw contract balance", async () => {
      await tokenMaster.createOccasion(ethers.utils.parseEther("1"), 1);

      await tokenMaster.connect(user1).buyTickets(1, 1, {
        value: ethers.utils.parseEther("1")
      });

      const before = await ethers.provider.getBalance(owner.address);

      const tx = await tokenMaster.withdraw(owner.address, ethers.utils.parseEther("1"));
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      const after = await ethers.provider.getBalance(owner.address);
      const withdrawn = after.add(gasUsed).sub(before);

      const diff = withdrawn.sub(ethers.utils.parseEther("1")).abs();
      expect(diff.lte(ethers.utils.parseEther("0.01"))).to.be.true;
    });
  });
});
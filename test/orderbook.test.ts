/* eslint-disable camelcase */
import { ethers } from "hardhat";
import { OrderBook, OrderBook__factory, TestToken, TestToken__factory } from "../typechain";
import { BigNumber, Signer } from "ethers";
import { expect } from "chai";
import { getBlockTimeStamp } from "./utils/help";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("OrderBook", async () => {
  let owner: Signer;
  let user1 : Signer;
  let treasury: Signer;
  let OrderBook: OrderBook__factory;
  let orderBook: OrderBook;

  let Token: TestToken__factory;
  let token: TestToken;
  beforeEach(async () => {
    Token = await ethers.getContractFactory("TestToken");
    token = await Token.deploy(ethers.utils.parseEther("1000"));
    await token.deployed();
    
    OrderBook = await ethers.getContractFactory("OrderBook");
    [owner, user1, treasury] = await ethers.getSigners();
    orderBook = await OrderBook.deploy(
      token.address,
      300,
      200,
      await treasury.getAddress()
    );
    await orderBook.deployed();
  });

  // it("createBuyMarketOrder", async () => {
  //   await expect(orderBook.createBuyMarketOrder()).to.be.revertedWith("Insufficient matic amount");
  //   await expect(orderBook.createBuyMarketOrder({value: ethers.utils.parseEther("300")})).to.be.revertedWith("Insufficient SellOrders");
  //   const blockTimeStamp: BigNumber = await getBlockTimeStamp();

  //   // CreateSellLimitOrder with (Owner)
  //   await token.approve(orderBook.address, ethers.utils.parseEther("200"));
  //   await orderBook.createLimitOrder(1, ethers.utils.parseEther("100"), blockTimeStamp, 1);

  //   const treasury1:BigNumber = await treasury.getBalance();
  //   const userBalance1:BigNumber = await user1.getBalance();
  //   await orderBook.connect(user1).createBuyMarketOrder({value: ethers.utils.parseEther("50")});
  //   const treasury2:BigNumber = await treasury.getBalance();
  //   const userBalance2:BigNumber = await user1.getBalance();

    
  //   // After createBuyMarketOrder, difference between userBalance1 and userBalance2 should be equals 50 matic.
  //   // expect(userBalance1.sub(userBalance2)).to.be.equals(ethers.utils.parseEther("50"));
  //   expect(await token.balanceOf(await user1.getAddress())).to.be.equals(ethers.utils.parseEther("48.5")); // fee 3%

  //   // After createLimitOrder,
  //   expect(await token.balanceOf(await owner.getAddress())).to.be.equals(ethers.utils.parseEther("900")); // 300 - 100

  //   // After createLimitOrder treasury token and matic balance
  //   expect(await token.balanceOf(await treasury.getAddress())).to.be.equals(ethers.utils.parseEther("1.5"));
  //   expect(treasury2.sub(treasury1)).to.be.equals(ethers.utils.parseEther("1")); // fee 2%
    
  //   // expect(userBalance1.sub(userBalance2)).to.be.equals(ethers.utils.parseEther("50")); AssertionError: Expected "50002360144000000000" to be equal 50000000000000000000
  
  // });

  // it("createSellMarketOrder", async () => {
  //   await expect(orderBook.createSellMarketOrder(0)).to.be.revertedWith("Invalid Token Amount");
  //   const blockTimeStamp: BigNumber = await getBlockTimeStamp();

  //   // CreateSellLimitOrder with (Owner)
  //   await token.approve(orderBook.address, ethers.utils.parseEther("200"));
  //   await expect(orderBook.createSellMarketOrder(ethers.utils.parseEther("1"))).to.be.revertedWith("Insufficient BuyOrders");
    
  //   await orderBook.connect(user1).createLimitOrder(1, ethers.utils.parseEther("100"), blockTimeStamp, 0, {
  //       value: ethers.utils.parseEther("100")
  //   });
    
  //   const treasury1:BigNumber = await treasury.getBalance();
  //   const ownerBalance1:BigNumber = await owner.getBalance();
  //   await orderBook.createSellMarketOrder(ethers.utils.parseEther("50"));
  //   const treasury2:BigNumber = await treasury.getBalance();
  //   const ownerBalance2:BigNumber = await owner.getBalance();

    
  //   // // After createBuyMarketOrder, difference between userBalance1 and userBalance2 should be equals 50 matic.
  //   // // expect(userBalance1.sub(userBalance2)).to.be.equals(ethers.utils.parseEther("50"));
  //   expect(await token.balanceOf(await user1.getAddress())).to.be.equals(ethers.utils.parseEther("50")); // fee 3%
  //   // expect(userBalance2.sub(userBalance1)).to.be.equals(ethers.utils.parseEther("48.5"));   Expected "48997621040000000000" to be equal 48500000000000000000

  //   // // After createLimitOrder,
  //   // expect(await token.balanceOf(await owner.getAddress())).to.be.equals(ethers.utils.parseEther("200")); // 300 - 100

  //   // // After createLimitOrder treasury token and matic balance
  //   // expect(await token.balanceOf(await treasury.getAddress())).to.be.equals(ethers.utils.parseEther("1.5"));
  //   // expect(treasury2.sub(treasury1)).to.be.equals(ethers.utils.parseEther("1")); // fee 2%
    
  //   // expect(userBalance1.sub(userBalance2)).to.be.equals(ethers.utils.parseEther("50")); AssertionError: Expected "50002360144000000000" to be equal 50000000000000000000
  
  // });

  it("createLimitOrder", async () => {
    const blockTimeStamp: BigNumber = await getBlockTimeStamp();
    await expect(orderBook.createLimitOrder(1, ethers.utils.parseEther("100"), blockTimeStamp, 0, {
        value: ethers.utils.parseEther("50")
    })).to.be.revertedWith("Invalid matic amount");
    await expect(orderBook.createLimitOrder(1, ethers.utils.parseEther("100"), blockTimeStamp, 1, {
        value: ethers.utils.parseEther("50")
    })).to.be.revertedWith("Invalid matic amount for createLimitSellOrder");
    // await expect(orderBook.createLimitOrder(1, ethers.utils.parseEther("100"), blockTimeStamp, 0, {
    //     value: ethers.utils.parseEther("100")
    // })).to.be.revertedWith("Invalid time limit");
    await orderBook.connect(user1).createLimitOrder(2, ethers.utils.parseEther("100"), blockTimeStamp.add("10000"), 0, {
        value: ethers.utils.parseEther("200")
    });
    await time.increase(3600);
    await orderBook.connect(user1).createLimitOrder(3, ethers.utils.parseEther("100"), blockTimeStamp, 0, {
        value: ethers.utils.parseEther("300")
    });

    await token.approve(orderBook.address, ethers.utils.parseEther("1000"));
    await time.increase(3600);
    await orderBook.createLimitOrder(1, ethers.utils.parseEther("100"), blockTimeStamp, 1);
    await time.increase(3600);
    await orderBook.createLimitOrder(5, ethers.utils.parseEther("100"), blockTimeStamp, 1);

    // console.log("activeBuyOrders", await orderBook.getLatestRate());
    console.log("Best Order", await orderBook.getLatestRate());
    
    
    // expect(await token.balanceOf(orderBook.address)).to.be.equals(ethers.utils.parseEther("100"));
    // const escrow: string = orderBook.address;
    // expect(await ethers.provider.getBalance(escrow)).to.be.equals(ethers.utils.parseEther("100"));
 })
});

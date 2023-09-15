/* eslint-disable camelcase */
import { ethers } from "hardhat";
import { OrderBook, OrderBook__factory, TestToken, TestToken__factory } from "../typechain";
import { Signer } from "ethers";

describe("OrderBook", async () => {
  let owner: Signer;
  let user1 : Signer;
  let user2: Signer;
  let OrderBook: OrderBook__factory;
  let orderBook: OrderBook;

  let ownerAddress: string;
  let user1Address: string;
  let user2Address: string;

  let Token: TestToken__factory;
  let token: TestToken;
  beforeEach(async () => {
    Token = await ethers.getContractFactory("TestToken");
    token = await Token.deploy(ethers.utils.parseEther("300"));
    await token.deployed();

    OrderBook = await ethers.getContractFactory("OrderBook");
    orderBook = await OrderBook.deploy(
      "0x1a53E3850f526974D476cCb35334F03A9F47346c",
      300,
      200
    );
    await orderBook.deployed();
    console.log("orderbook address: ", orderBook.address);

    [owner, user1, user2] = await ethers.getSigners();

    ownerAddress =  await owner.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();
    console.log("owner Address: ", await owner.getAddress());
    console.log("User1 Address: ", await user1.getBalance());
    console.log("User2 Address: ", await user2.getAddress());
  });

  it("createBuyMarketOrder", async () => {
    const tx = await user1.sendTransaction({
      to: orderBook.address,
      value: ethers.utils.parseEther("3000000000000000.0"),
    });

    await orderBook.createBuyMarketOrder();

    console.log("tx ", tx);
    console.log("User matic balance: ", await owner.getBalance());
    console.log("Orderbook matic balance: ", await ethers.provider.getBalance(orderBook.address));
  });
});

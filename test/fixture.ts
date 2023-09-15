import { ethers } from "hardhat";

export async function basicFixture() {
    const [owner] = await ethers.getSigners();
    const OrderBookFactory = await ethers.getContractFactory("OrderBook");
    const orderBook = await OrderBookFactory.deploy("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48");
    await orderBook.deployed();

    return {orderBook, owner};
}
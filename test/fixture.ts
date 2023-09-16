import { ethers } from "hardhat";

export async function basicFixture() {
    const [owner, treasury, user2, user3] = await ethers.getSigners();
    
    // deploy test token
    const tokenFactory = await ethers.getContractFactory("ACME");
    const token = await tokenFactory.deploy();
    await token.deployed();

    // deploy test oracle
    const oracleFactory = await ethers.getContractFactory("Oracle");
    const oracle = await oracleFactory.deploy("MATIC-USD", 9);
    await oracle.deployed();

    const OrderBookFactory = await ethers.getContractFactory("OrderBook");
    const orderBook = await OrderBookFactory.deploy(
        token.address,
        treasury.address,
        oracle.address
    );
    await orderBook.deployed();


    // write first price on oracle
    await oracle.writePrice(ethers.utils.parseUnits("0.54", 9));

    return {orderBook, owner};
}
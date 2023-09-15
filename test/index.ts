import { loadFixture } from "ethereum-waffle";
import { basicFixture } from "./fixture";

describe("Orderbook test", () => {
    it("Sort function", async () => {
        const {orderBook, owner} = await loadFixture(basicFixture);
        await orderBook.insert(6);
        console.log("after insert 1: ", await orderBook.values(0), await orderBook.values(1), await orderBook.values(2), await orderBook.values(3),await orderBook.values(4),await orderBook.values(5),await orderBook.values(6));
    })
});
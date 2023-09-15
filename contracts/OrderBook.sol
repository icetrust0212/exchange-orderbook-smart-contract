// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOrderBook} from "./interfaces/IOrderBook.sol";

contract OrderBook is IOrderBook, Ownable, ReentrancyGuard {
    receive() payable external{

    }
    Order[] public activeBuyOrders;
    Order[] public activeSellOrders;
    Order[] public fullfilledOrders;

    address public tokenAddress;
    uint256 public nonce = 0;

    uint256 public constant BASE_BIPS = 10000;
    uint256 public buyAdderBIPS;
    uint256 public sellAdderBIPS;

    mapping(address => uint256) public OrderCountByUser; // Add Count

    constructor(address _token, uint256 _buyAdderBIPS, uint256 _sellAdderBIPS) {
        require(_token != address(0), "Invalid Token");
        require(_buyAdderBIPS < BASE_BIPS, "Invalid Buy Fee");
        require(_sellAdderBIPS < BASE_BIPS, "Invalid Sell Fee");
        tokenAddress = _token;
        buyAdderBIPS = _buyAdderBIPS;
        sellAdderBIPS = _sellAdderBIPS;
    }

    /**
     * @dev Create new buy market order which will be executed instantly
     */
    function createBuyMarketOrder() external payable nonReentrant {
        require(msg.value > 0, "Insufficient matic amount");
        Order memory marketOrder = Order(
            nonce,
            msg.sender,
            OrderType.BUY,
            0,
            0,
            0,
            msg.value,
            msg.value,
            false,
            true,
            false,
            0,
            0
        );
        nonce++;

        uint256 tokenAmount = 0;
        require(activeSellOrders.length > 0, "Insufficient SellOrders");
        for (uint256 i = activeSellOrders.length - 1; i >= 0; i--) {
            Order storage sellOrder = activeSellOrders[i];
            if (isInvalidOrder(sellOrder)) {
                // remove expired sell orders from active sell order list
                // removeLastFromSellLimitOrder();
                continue;
            }

            uint256 desiredMaticValue = sellOrder.desiredPrice *
                sellOrder.remainQuantity;
            if (marketOrder.remainMaticValue >= desiredMaticValue) {
                // remove fullfilled order from active sell order list
                // removeLastFromSellLimitOrder();
                // send matic to seller
                payable(sellOrder.trader).transfer(desiredMaticValue - desiredMaticValue * sellAdderBIPS / BASE_BIPS);
                // decrease remain matic value
                marketOrder.remainMaticValue -= desiredMaticValue;
                tokenAmount += sellOrder.remainQuantity;
                // fullfill sell limitOrder
                sellOrder.isFilled = true;
                sellOrder.remainQuantity = 0;
                sellOrder.lastTradeTimestamp = block.timestamp;
            } else {
                // partially fill sell limitOrder
                // send matic to seller
                payable(sellOrder.trader).transfer(
                    marketOrder.remainMaticValue - desiredMaticValue * sellAdderBIPS / BASE_BIPS
                );
                uint256 purchasedTokenAmount = marketOrder.remainMaticValue /
                    sellOrder.desiredPrice;
                marketOrder.remainMaticValue = 0;
                // decrease remain token amount of sell limitOrder
                sellOrder.remainQuantity -= purchasedTokenAmount;
                tokenAmount += purchasedTokenAmount;
                sellOrder.lastTradeTimestamp = block.timestamp;
                break;
            }
        }

        if (marketOrder.remainMaticValue > 0) {
            // In this case, sell token supply is insufficient than buy matic amount, so revert
            revert("Insufficient Token Supply");
        }

        fullfilledOrders.push(marketOrder);
        cleanLimitOrders();

        // transfer token to buyer
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount - tokenAmount * buyAdderBIPS / BASE_BIPS);
        OrderCountByUser[msg.sender]++;
    }

    function removeLastFromSellLimitOrder() internal {
        Order memory lastOrder = activeSellOrders[activeSellOrders.length - 1];
        activeSellOrders.pop();
        fullfilledOrders.push(lastOrder);
    }

    /**
     * @dev Create new sell market order which will be executed instantly
     */
    function createSellMarketOrder(uint256 quantity) external nonReentrant {
        require(quantity > 0, "Invalid Token Amount");
        // Token should be left user wallet instantly
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), quantity);

        Order memory marketOrder = Order(
            nonce,
            msg.sender,
            OrderType.SELL,
            0,
            quantity,
            quantity,
            0,
            0,
            false,
            true,
            false,
            0,
            0
        );

        nonce++;

        uint256 maticAmount = 0;
        require(activeBuyOrders.length > 0, "Insufficient BuyOrders");
        for (uint256 i = activeBuyOrders.length - 1; i >= 0; i--) {
            Order storage buyOrder = activeBuyOrders[i];
            if (isInvalidOrder(buyOrder)) {
                // remove expired buy orders from active buy order list
                // removeLastFromBuyLimitOrder();
                continue;
            }

            uint256 desiredTokenAmount = buyOrder.remainQuantity;
            if (marketOrder.remainQuantity >= desiredTokenAmount) {
                // remove fullfilled order from active buy order list
                // removeLastFromBuyLimitOrder();
                // send token to buyer
                IERC20(tokenAddress).transfer(
                    buyOrder.trader,
                    desiredTokenAmount - desiredTokenAmount * buyAdderBIPS / BASE_BIPS 
                );
                // decrease remain token amount
                marketOrder.remainQuantity -= desiredTokenAmount;
                maticAmount += buyOrder.remainMaticValue;
                // fullfill buy limitOrder
                buyOrder.isFilled = true;
                buyOrder.remainMaticValue = 0;
                buyOrder.remainQuantity = 0;
                buyOrder.lastTradeTimestamp = block.timestamp;
            } else {
                // partially fill buy limitOrder
                // send token to buyer
                IERC20(tokenAddress).transfer(
                    buyOrder.trader,
                    marketOrder.remainQuantity - marketOrder.remainQuantity * buyAdderBIPS / BASE_BIPS 
                );
                uint256 usedMaticAmount = marketOrder.remainQuantity *
                    buyOrder.desiredPrice;
                // decrease remain token amount of sell limitOrder
                buyOrder.remainMaticValue -= usedMaticAmount;
                buyOrder.remainQuantity -= marketOrder.remainQuantity;
                maticAmount += usedMaticAmount;
                buyOrder.lastTradeTimestamp = block.timestamp;
                marketOrder.remainQuantity = 0;
                break;
            }
        }

        if (marketOrder.remainQuantity > 0) {
            // In this case, buy token supply is insufficient than buy matic amount, so revert
            revert("Insufficient market Supply");
        }

        fullfilledOrders.push(marketOrder);
        cleanLimitOrders();

        // transfer token to buyer
        payable(msg.sender).transfer(maticAmount - maticAmount * sellAdderBIPS / BASE_BIPS);
        OrderCountByUser[msg.sender]++;
    }

    function removeLastFromBuyLimitOrder() internal {
        Order memory lastOrder = activeBuyOrders[activeBuyOrders.length - 1];
        activeBuyOrders.pop();
        fullfilledOrders.push(lastOrder);
    }

    /**
     * @dev Create new limit order
     */
    function createLimitOrder(
        uint256 desiredPrice,
        uint256 quantity,
        uint256 timeInForce,
        OrderType orderType
    ) external payable {
        if (orderType == OrderType.BUY) {
            require(
                msg.value == desiredPrice * quantity,
                "Invalid matic amount"
            );
        } else {
            require(msg.value == 0, "Invalid matic amount");
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                quantity
            );
        }
        require(timeInForce > block.timestamp, "Invalid time limit");

        Order memory newOrder = Order(
            nonce,
            msg.sender,
            orderType,
            desiredPrice,
            quantity,
            quantity,
            msg.value,
            msg.value,
            false,
            false,
            false,
            timeInForce,
            0
        );

        nonce++;

        // Insert newOrder into active sell/buy limit order list. It should be sorted by desiredPrice
        // For Sell orders, we sort it DESC, so it should be [9,8,.., 2,1,0]
        // For Buy orders, we sort it ASC, so it should be [0,1,2,...,8,9]
        // In this way, we iterate order list from end, and pop the last order from active order list
        if (orderType == OrderType.BUY) {
            insertBuyLimitOrder(newOrder);
        } else {
            insertSellLimitOrder(newOrder);
        }

        if (activeBuyOrders.length > 0 && activeSellOrders.length > 0) {
            executeLimitOrders();
        }
        OrderCountByUser[msg.sender]++;
    }

    // Sort ASC [0, 1, 2, ...]
    function insertBuyLimitOrder(Order memory newLimitBuyOrder) internal {
        uint256 i = activeBuyOrders.length;

        activeBuyOrders.push(newLimitBuyOrder);
        while (
            i > 0 &&
            activeBuyOrders[i - 1].desiredPrice > newLimitBuyOrder.desiredPrice
        ) {
            activeBuyOrders[i] = activeBuyOrders[i - 1];
            i--;
        }

        activeBuyOrders[i] = newLimitBuyOrder;
    }

    // Sort DESC [9, 8, ..., 1, 0]
    function insertSellLimitOrder(Order memory newLimitSellOrder) internal {
        uint256 i = activeSellOrders.length;

        activeSellOrders.push(newLimitSellOrder);

        while (
            i > 0 &&
            activeSellOrders[i - 1].desiredPrice <
            newLimitSellOrder.desiredPrice
        ) {
            activeSellOrders[i] = activeSellOrders[i - 1];
            i--;
        }

        activeSellOrders[i] = newLimitSellOrder;
    }

    // We execute matched buy and sell orders one by one
    // This is called whenever new limit order is created, or can be called from backend intervally
    function executeLimitOrders() public {
        // clean
        cleanLimitOrders();
        require(
            activeBuyOrders.length > 0 && activeSellOrders.length > 0,
            "No Sell or Buy limit orders exist"
        );

        Order storage buyOrder = activeBuyOrders[activeBuyOrders.length - 1];
        Order storage sellOrder = activeSellOrders[activeSellOrders.length - 1];

        if (buyOrder.desiredPrice >= sellOrder.desiredPrice) {
            // we only execute orders when buy price is higher or equal than sell price
            uint256 tokenAmount = buyOrder.remainQuantity >=
                sellOrder.remainQuantity
                ? sellOrder.remainQuantity
                : buyOrder.remainQuantity;

            uint256 sellerDesiredMaticAmount = sellOrder.desiredPrice *
                tokenAmount;
            // send matic to seller
            payable(sellOrder.trader).transfer(sellerDesiredMaticAmount - sellerDesiredMaticAmount * sellAdderBIPS / BASE_BIPS);
            // decrease remain matic value
            buyOrder.remainMaticValue -= sellerDesiredMaticAmount;
            buyOrder.remainQuantity -= tokenAmount;
            buyOrder.lastTradeTimestamp = block.timestamp;

            IERC20(tokenAddress).transfer(buyOrder.trader, tokenAmount - tokenAmount * buyAdderBIPS / BASE_BIPS);
            sellOrder.remainQuantity -= tokenAmount;
            sellOrder.lastTradeTimestamp = block.timestamp;

            if (buyOrder.remainQuantity == 0) {
                buyOrder.isFilled = true;
                if (buyOrder.remainMaticValue > 0) {
                    // refund
                    payable(buyOrder.trader).transfer(
                        buyOrder.remainMaticValue
                    );
                    buyOrder.remainMaticValue = 0;
                }
                // fullfilledOrders.push(buyOrder);
                removeLastFromBuyLimitOrder();
            }
            if (sellOrder.remainQuantity == 0) {
                sellOrder.isFilled = true;
                // fullfilledOrders.push(sellOrder);
                removeLastFromSellLimitOrder();
            }
        }
    }

    function isInvalidOrder(Order memory order) public view returns (bool) {
        return
            order.isFilled ||
            order.timeInForce < block.timestamp ||
            order.remainQuantity == 0;
    }

    function cleanLimitOrders() internal {
        while (
            activeBuyOrders.length > 0 &&
            isInvalidOrder(activeBuyOrders[activeBuyOrders.length - 1])
        ) {
            removeLastFromBuyLimitOrder();
        }
        while (
            activeSellOrders.length > 0 &&
            isInvalidOrder(activeSellOrders[activeSellOrders.length - 1])
        ) {
            removeLastFromSellLimitOrder();
        }
    }

    function getLatestRate()
        external
        view
        returns (Order memory, Order memory)
    {
        Order memory bestBidOrder = activeBuyOrders[activeBuyOrders.length - 1];
        Order memory bestAskOrder = activeSellOrders[
            activeSellOrders.length - 1
        ];
        return (bestBidOrder, bestAskOrder);
    }

    function orderBook(
        uint256 depth,
        OrderType orderType
    ) external view returns (Order[] memory) {
        if (orderType == OrderType.BUY) {
            require(
                depth <= activeBuyOrders.length,
                "Depth could not be larger than activeBuyOrders length"
            );
            Order[] memory bestActiveBuyOrders = new Order[](depth);
            if (depth == activeBuyOrders.length) {
                return activeBuyOrders;
            }
            for (
                uint256 i = activeBuyOrders.length - 1;
                i >= activeBuyOrders.length - depth;
                i--
            ) {
                bestActiveBuyOrders[i] = activeBuyOrders[i];
            }
            return bestActiveBuyOrders;
        } else {
            require(
                depth <= activeSellOrders.length,
                "Depth could not be larger than activeSellOrders length"
            );
            Order[] memory bestActiveSellOrders = new Order[](depth);
            if (depth == activeSellOrders.length) {
                return activeSellOrders;
            }
            for (
                uint256 i = activeSellOrders.length - 1;
                i >= activeSellOrders.length - depth;
                i--
            ) {
                bestActiveSellOrders[i] = activeBuyOrders[i];
            }
            return bestActiveSellOrders;
        }
    }

    function getOrderById(uint256 id) public view returns (Order memory) {
       require(id > 0 && id < nonce, "Invalid Id");
       for (uint256 i = 0; i < activeBuyOrders.length; i ++) {
            Order memory order = activeBuyOrders[i];
            if ( id == order.id) {
                return order;
            }
       }
       for (uint256 i = 0; i < activeSellOrders.length; i ++) {
            Order memory order = activeSellOrders[i];
            if ( id == order.id) {
                return order;
            }
       }
       for (uint256 i = 0; i < fullfilledOrders.length; i ++) {
            Order memory order = fullfilledOrders[i];
            if ( id == order.id) {
                return order;
            }
       }

       revert("Invalid Order");
    }

    function getOrdersByUser(
        address user
    ) external view returns (Order[] memory, Order[] memory, Order[] memory) {
        require(OrderCountByUser[user] > 0, "User did not make any order");
        Order[] memory activeBuyOrdersByUser = new Order[](OrderCountByUser[user]);
        uint256 k;
        for (uint256 i = 0; i < activeBuyOrders.length; i ++) {
            Order memory order = activeBuyOrders[i];
            if ( user == order.trader) {
                activeBuyOrdersByUser[k] = order;
                k++;
            }
        }
        uint256 toDrop1 = OrderCountByUser[user] - k;
        if (toDrop1 > 0) {
            assembly {
                mstore(activeBuyOrdersByUser, sub(mload(activeBuyOrdersByUser), toDrop1))
            }
        }
        k = 0;

        Order[] memory activeSellOrdersByUser = new Order[](OrderCountByUser[user]);
        for (uint256 i = 0; i < activeSellOrders.length; i ++) {
            Order memory order = activeSellOrders[i];
            if (user == order.trader) {
                activeSellOrdersByUser[k] = order;
                k++;
            }
        }
        uint256 toDrop2 = OrderCountByUser[user] - k;
        if (toDrop2 > 0) {
            assembly {
                mstore(activeBuyOrdersByUser, sub(mload(activeBuyOrdersByUser), toDrop2))
            }
        }
        k = 0;

        Order[] memory fullfilledOrdersByUser = new Order[](OrderCountByUser[user]);
        for (uint256 i = 0; i < fullfilledOrders.length; i ++) {
            Order memory order = fullfilledOrders[i];
            if (user == order.trader) {
                fullfilledOrdersByUser[k] = order;
                k++;
            }
        }
        uint256 toDrop3 = OrderCountByUser[user] - k;
        if (toDrop3 > 0) {
            assembly {
                mstore(fullfilledOrdersByUser, sub(mload(fullfilledOrdersByUser), toDrop3))
            }
        }

        return (activeBuyOrdersByUser, activeSellOrdersByUser, fullfilledOrdersByUser);
    }

    function cancelOrder(uint256 id) external returns(bool) {
        require(id > 0 && id < nonce, "Invalid Id");
        (bool isActiveBuyOrder, uint256 i) = getIndex(id);
        Order storage order = isActiveBuyOrder ? activeBuyOrders[i] : activeSellOrders[i];
        require(order.trader == msg.sender, "Invaild User");

        order.isFilled = true;
        order.isCanceled = true;

        if (isActiveBuyOrder) {
            payable(order.trader).transfer(order.remainMaticValue);
        } else {
            IERC20(tokenAddress).transfer(
                order.trader,
                order.remainQuantity
            );
        }

        return true;
    }

    function withDrawMatic(uint256 amount) external onlyOwner returns (bool) {
        require(
            amount > 0 && amount <= address(this).balance,
            "Invalid amount"
        );
        payable(msg.sender).transfer(address(this).balance);
        return true;
    }

    function withdrawTokens(
        uint256 amount
    ) external onlyOwner returns (bool success) {
        require(
            amount > 0 &&
                amount <= IERC20(tokenAddress).balanceOf(address(this)),
            "Invalid amount"
        );
        IERC20(tokenAddress).transfer(msg.sender, amount);
        return true;
    }

    function getIndex(uint256 id) public view returns (bool, uint256) {
        for (uint256 i = 0; i < activeBuyOrders.length; i ++) {
            Order memory order = activeBuyOrders[i];
            if ( id == order.id ) {
                return (order.maticValue == 0, order.id);
            }
       }

       for (uint256 i = 0; i < activeSellOrders.length; i ++) {
            Order memory order = activeSellOrders[i];
            if ( id == order.id ) {
                return (order.maticValue == 0, order.id);
            }
       }
       revert("Invalid Id");
    }

    function setBuyAdderBIPS(uint256 _buyAdderBIPS) external onlyOwner {
        require(buyAdderBIPS != _buyAdderBIPS, "Same BuyAdderBIPS");
        require(_buyAdderBIPS < BASE_BIPS, "Invalid BuyAdderBIPS");
        buyAdderBIPS = _buyAdderBIPS;
    }

    function setSellAdderBIPS(uint256 _sellAdderBIPS) external onlyOwner {
        require(sellAdderBIPS != _sellAdderBIPS, "Invalid SellAdderBIPS");
        require(_sellAdderBIPS < BASE_BIPS, "Invalid SellAdderBIPS");
        sellAdderBIPS = _sellAdderBIPS;
    }
}

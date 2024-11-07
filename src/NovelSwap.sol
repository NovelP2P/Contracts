// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract P2PHTLCSwap is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _orderIds;

    uint64 public _swapIds = 0; 

    struct Order {
        uint256 orderId;
        address maker;
        address tokenToSell;
        address tokenToBuy;
        uint256 amountToSell;
        uint256 amountToBuy;
        uint256 minTradeAmount;  // Minimum trade size
        uint256 maxTradeAmount;  // Maximum trade size
        bool partialFillAllowed;
        uint256 timelock; 
        bytes32 hashlock;
        bool isActive;
        bytes32[] activeSwaps;   // Track all active swaps for this order
    }
    
    struct Swap {
        uint256 swapId;
        uint256 orderId;
        address initiator;       // Order maker
        address participant;     // Order taker
        address initiatorToken;
        address participantToken;
        uint256 initiatorAmount;
        uint256 participantAmount;
        bytes32 hashlock;
        uint256 timelock;
        SwapStatus status;
    }
    
    enum SwapStatus {
        INVALID,
        ACTIVE,
        COMPLETED,
        REFUNDED,
        EXPIRED
    }
    
    // Main storage
    mapping(uint256 => Order) public orders;
    mapping(uint256 => Swap) public swaps;
    
    // Order book organization
    mapping(address => mapping(address => uint256[])) public orderBook;  // tokenA => tokenB => orderIds
    mapping(address => uint256[]) public userOrders;  // user => their orderIds
    
    //order to swap
    mapping(uint256 => uint256[]) public orderToSwap;
    // Events
    event OrderCreated(
        uint256 indexed orderId,
        address indexed maker,
        address tokenToSell,
        address tokenToBuy,
        uint256 amountToSell,
        uint256 amountToBuy
    );
    
    event OrderCancelled(uint256 indexed orderId);
    event OrderUpdated(uint256 indexed orderId);
    
    event SwapInitiated(
        uint256 indexed swapId,
        uint256 indexed orderId,
        address indexed participant,
        uint256 initiatorAmount,
        uint256 participantAmount
    );
    
    event SwapCompleted(uint256 indexed swapId);
    event SwapRefunded(uint256 indexed swapId);
    
    // Modifiers
    modifier onlyOrderMaker(uint256 swapId) {
        uint256 _orderId = swaps[swapId].orderId;
        require(orders[_orderId].maker == msg.sender, "Not order maker");
        _;
    }
    
    modifier orderExists(uint256 orderId) {
        require(orders[orderId].maker != address(0), "Order does not exist");
        _;
    }
    
    modifier swapExists(uint256 swapId) {
        require(swaps[swapId].status != SwapStatus.INVALID, "Swap does not exist");
        _;
    }
    
    // Order Management Functions
    function createOrder(
        address _tokenToSell,
        address _tokenToBuy,
        uint256 _amountToSell,
        uint256 _amountToBuy,
        uint256 _minTradeAmount,
        uint256 _maxTradeAmount,
        bool _partialFillAllowed,
        uint256 _timelock,
        string  memory _preImage
    ) external nonReentrant payable returns (uint256) {
        require(_timelock > block.timestamp, "Invalid timelock");
        require(_amountToSell > 0 && _amountToBuy > 0, "Invalid amounts");
        require(_minTradeAmount <= _maxTradeAmount, "Invalid trade limits");
        require(_maxTradeAmount <= _amountToSell, "Max trade exceeds total");
        
        uint256 orderId = _orderIds.current();
        
        // Lock tokens
        if(_tokenToSell == address(0)) {
            require(msg.value == _amountToSell, "Invalid ETH amount");
        } else {
            require(
                IERC20(_tokenToSell).transferFrom(msg.sender, address(this), _amountToSell),
                "Token transfer failed"
            );
        }
        bytes32 secret = keccak256(abi.encodePacked(_preImage));

        // Create order
        orders[orderId] = Order({
            orderId: orderId,
            maker: msg.sender,
            tokenToSell: _tokenToSell,
            tokenToBuy: _tokenToBuy,
            amountToSell: _amountToSell,
            amountToBuy: _amountToBuy,
            minTradeAmount: _minTradeAmount,
            maxTradeAmount: _maxTradeAmount,
            partialFillAllowed: _partialFillAllowed,
            timelock: _timelock,
            hashlock:secret,
            isActive: true,
            activeSwaps: new bytes32[](0)
        });
        
        // Add to order book
        orderBook[_tokenToSell][_tokenToBuy].push(orderId);
        userOrders[msg.sender].push(orderId);
        _orderIds.increment();
        
        emit OrderCreated(
            orderId,
            msg.sender,
            _tokenToSell,
            _tokenToBuy,
            _amountToSell,
            _amountToBuy
        );
        
        return orderId;
    }
    
    function initiateSwap(
        uint256 orderId,
        uint256 takeAmount,
        bytes32 hashlock,
        uint256 timelock
    ) external payable nonReentrant{
        Order storage order = orders[orderId];
        require(order.isActive, "Order not active");
        require(block.timestamp < order.timelock, "Order expired");
        // require(msg.sender != order.maker, "Cannot swap with self");
        require(timelock < order.timelock, "Swap timelock exceeds order");
        require(takeAmount >= order.minTradeAmount, "Below min trade");
        require(takeAmount <= order.maxTradeAmount, "Exceeds max trade");
        
        // Calculate proportional amounts
        uint256 giveAmount = (takeAmount * order.amountToBuy) / order.amountToSell;
        
        // Lock taker tokens
        if(order.tokenToBuy == address(0)) {
            require(msg.value == giveAmount, "Invalid ETH amount");
        } else {
            require(
                IERC20(order.tokenToBuy).transferFrom(msg.sender, address(this), giveAmount),
                "Token transfer failed"
            );
        }
        
        // Create swap
        uint256 swapId = _swapIds;
        
        swaps[swapId] = Swap({
            swapId: swapId,
            orderId: orderId,
            initiator: order.maker,
            participant: msg.sender,
            initiatorToken: order.tokenToSell,
            participantToken: order.tokenToBuy,
            initiatorAmount: takeAmount,
            participantAmount: giveAmount,
            hashlock: hashlock,
            timelock: timelock,
            status: SwapStatus.ACTIVE
        });
        
        // Update order
        orderToSwap[orderId].push(swapId);

        if(!order.partialFillAllowed || takeAmount == order.amountToSell) {
            order.isActive = false;
        }
        _swapIds++;
        
        emit SwapInitiated(swapId, orderId, msg.sender, takeAmount, giveAmount);
        
    }
    
    function completeSwap(uint256 swapId, string memory preimage) external nonReentrant swapExists(swapId) onlyOrderMaker(swapId) {
        Swap storage swap = swaps[swapId];
        require(swap.status == SwapStatus.ACTIVE, "Invalid swap status");
        require(block.timestamp < swap.timelock, "Swap expired");
        require(keccak256(abi.encodePacked(preimage)) == swap.hashlock, "Invalid preimage");
        
        swap.status = SwapStatus.COMPLETED;
        
        // Transfer tokens
        transferTokens(swap.initiatorToken, swap.participant, swap.initiatorAmount);
        transferTokens(swap.participantToken, swap.initiator, swap.participantAmount);
        
        // Update order's remaining amount
        Order storage order = orders[swap.orderId];
        order.amountToSell -= swap.initiatorAmount;
        if(order.amountToSell < order.minTradeAmount) {
            order.isActive = false;
        }
        
        emit SwapCompleted(swapId);
    }
    
    function refundSwap(uint256 swapId) external nonReentrant swapExists(swapId) {
        Swap storage swap = swaps[swapId];
        require(swap.status == SwapStatus.ACTIVE, "Invalid swap status");
        require(block.timestamp >= swap.timelock, "Timelock not expired");
        
        swap.status = SwapStatus.REFUNDED;
        
        // Return tokens to original owners
        transferTokens(swap.initiatorToken, swap.initiator, swap.initiatorAmount);
        transferTokens(swap.participantToken, swap.participant, swap.participantAmount);
        
        emit SwapRefunded(swapId);
    }
    
    // Order Management Helper Functions
    function cancelOrder(uint256 orderId) external nonReentrant onlyOrderMaker(orderId) {
        Order storage order = orders[orderId];
        require(order.isActive, "Order not active");
        require(order.activeSwaps.length == 0, "Has active swaps");
        
        order.isActive = false;
        
        // Return remaining tokens
        transferTokens(order.tokenToSell, order.maker, order.amountToSell);
        
        // Remove from order book
        removeFromOrderBook(order.tokenToSell, order.tokenToBuy, orderId);
        
        emit OrderCancelled(orderId);
    }
    
    // View Functions
    function getOrderBook(address tokenA, address tokenB) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return orderBook[tokenA][tokenB];
    }
    
    function getUserOrders(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userOrders[user];
    }
    
    // Internal Helper Functions
    function transferTokens(address token, address to, uint256 amount) internal {
        if(token == address(0)) {
            payable(to).transfer(amount);
        } else {
            require(IERC20(token).transfer(to, amount), "Token transfer failed");
        }
    }
    
    function removeFromOrderBook(address tokenA, address tokenB, uint256 orderId) internal {
        uint256[] storage allOrders = orderBook[tokenA][tokenB];
        for(uint i = 0; i < allOrders.length; i++) {
            if(allOrders[i] == orderId) {
                allOrders[i] = allOrders[allOrders.length - 1];
                allOrders.pop();
                break;
            }
        }
        orderBook[tokenA][tokenB] = allOrders;
    }
}
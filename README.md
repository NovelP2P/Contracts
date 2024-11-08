# NovelSwap

This project is a peer-to-peer (P2P) token swapping platform that utilizes cryptographic hashlocks and timelocks for secure, conditional token transfers. The system allows for flexible trading by enabling partial swaps and does not rely on automated market makers (AMMs). Instead, it operates through a decentralized order book, allowing users to directly exchange tokens based on their own conditions.


For the UI code [visit here]("https://github.com/NovelP2P/P2P-UI")  
For video demo [Click here]("https://www.loom.com/share/ceb472400a95443c85f0d50646595f90")  
## Features

### Order Creation and Management
- **Direct Order Placement**: Users can create buy/sell orders specifying the token to sell, the token they want in return, the amounts, and minimum/maximum trade amounts.
- **Hashlock and Timelock Protection**: Orders are secured by a cryptographic hashlock and a timelock, ensuring that only parties with the correct pre-image can complete the transaction within a specified timeframe.
- **Partial Fill Option**: Users can allow partial fills on their orders, which permits multiple trades against a single order until the total amount is fulfilled.

### Secure Swapping Mechanism
- **Cryptographic Hashlock**: Swaps require a hashed secret for secure transaction completion, ensuring only parties with the pre-image can finalize the swap.
- **Timelock**: A time-bound condition that limits how long an order or swap remains active, providing a fail-safe return of funds if the trade isn't completed within the allocated time.
- **Flexible Token Support**: Both ERC20 tokens and ETH can be used, making it versatile for various asset swaps.

### Order Book and User Management
- **Order Book Tracking**: Orders are organized by token pairs (tokenToSell → tokenToBuy) to facilitate easy matching and order discovery.
- **User Order Tracking**: Users can view their own orders, and order statuses are updated based on trades and completions.
- **Swap Tracking**: Each order tracks its related swaps to ensure secure and transparent transaction history.

## How It Works

### 1. Order Creation
Users create orders with details including:
- Token to sell and token to buy
- Amounts and trade limits
- Hashlock and timelock for security
- Option for partial fills

Upon order creation:
- Tokens are locked in the contract.
- The order is added to the order book.
- The creator specifies a pre-image (secret) to generate a hashlock for transaction security.

### 2. Swap Initiation
A user can initiate a swap against an existing order if they:
- Match the order’s trade limits and amounts.
- Provide a valid hashlock and timelock within the order’s limits.

When a swap is initiated, the contract locks the tokens from both parties, creating a secure, conditional environment for trade execution.

### 3. Swap Completion
The order maker can complete the swap if:
- They provide the correct pre-image matching the swap's hashlock.
- The swap is within the timelock period.

Once verified, the contract transfers tokens to both parties, finalizing the swap.

### 4. Swap Refund
If the timelock expires and the swap is not completed, either party can initiate a refund, returning their locked tokens.

## Smart Contract Architecture

### Structs

- **Order**: Contains all order-related details including token addresses, amounts, limits, hashlock, timelock, and a list of active swaps.
- **Swap**: Contains swap-specific details including order ID, participant details, token amounts, hashlock, timelock, and current status.

### Enums

- **SwapStatus**: Defines the possible statuses for a swap: `INVALID`, `ACTIVE`, `COMPLETED`, `REFUNDED`, and `EXPIRED`.

### Events

- **OrderCreated**: Emitted when a new order is created.
- **OrderCancelled**: Emitted when an order is canceled.
- **OrderUpdated**: Emitted when an order is updated.
- **SwapInitiated**: Emitted when a swap is initiated.
- **SwapCompleted**: Emitted when a swap is completed.
- **SwapRefunded**: Emitted when a swap is refunded.

## Functions

### Order Management

- **createOrder**: Allows users to create a new order, specifying tokens, amounts, limits, and cryptographic parameters.
- **cancelOrder**: Allows the order maker to cancel an active order, returning any remaining locked tokens.

### Swap Management

- **initiateSwap**: Starts a swap on an existing order, locking both parties' tokens and recording the swap details.
- **completeSwap**: Completes the swap by verifying the provided pre-image matches the hashlock, transferring tokens to both parties.
- **refundSwap**: Refunds tokens if the timelock has expired without swap completion.

### Utility

- **getOrderBook**: Returns the list of order IDs for a specific token pair.
- **getUserOrders**: Returns a list of order IDs created by a specific user.
- **transferTokens**: Internal function to handle token or ETH transfers.

## Installation and Setup

### Prerequisites

- Solidity 0.8.x
- Node.js
- Foundary for smart contract development and testing
- [OpenZeppelin](https://openzeppelin.com/) libraries for security and utility contracts

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/NovelP2P/Contracts
   cd Contracts
   ```

2. Compile and deploy smart contracts:
   ```bash
   forge build
   forge test
   ```

## Usage

- **Create an Order**: Call `createOrder` with relevant parameters to place an order on the platform.
- **Initiate a Swap**: Call `initiateSwap` with the matching order’s ID and token amounts.
- **Complete or Refund a Swap**: The order maker can complete the swap by providing the correct pre-image within the timelock. If the swap expires, either party can call `refundSwap` to retrieve their assets.


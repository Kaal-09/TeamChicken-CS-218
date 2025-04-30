#  TokenMaster - Decentralized Ticketing on Ethereum

TokenMaster is a smart contract-based event ticketing system built using Solidity and ERC-721 tokens. It allows event creators to list events (called "occasions") and lets users buy, sell, cancel, and resell tickets securely and transparently on the blockchain.

---

##  Features

###  Version 1 Highlights:
- Event creators can **list new occasions** with details like cost, date, time, and location.
- Users can **buy tickets** (1 per user per event) with seat selection.
- Allows **ticket cancellation** with 90% refund to the buyer and 10% to the event creator.
- **Resale functionality**: Ticket owners can list their ticket for resale.
- Tracks ticket ownership and **seat allocation**.
- Stores all data like occasions, bookings, and resales **on-chain**.

### Limitations of Version 1:
- A user can **only buy one ticket per event**.
- Ticket lookup and event management are a bit complex due to nested mappings.
- All metadata is stored on-chain which can be **gas-heavy**.

---

##  Version 2 Enhancements:
To overcome limitations in version 1, a new streamlined version was created with:

### Improvements:
- Allows users to **buy multiple tickets** in a single transaction.
- Simplified structure with **flat occasion and ticket tracking**.
- **Efficient resale listing**: Caps resale price at **1.5x original price**.
- Utility functions to **fetch all occasions and specific details**.

### Data Stored:
- `Occasion`: ID, cost, total seats, seats taken.
- `ResaleListing`: tokenId, price, seller.
- Mappings to track:
  - Seat ownership per occasion.
  - Resale listings.
  - Tickets bought per user.

---

##  Smart Contracts

### Version 1 Contract:
File: `contracts/TokenMasterV1.sol`

> Built using Solidity ^0.8.9 and OpenZeppelin ERC721.

### Version 2 Contract:
File: `contracts/TokenMasterV2.sol`

> Built using Solidity ^0.8.19 and a restructured data layout for efficiency.

---

## Getting Started

1. Clone the repository.
2. Install dependencies:
   ```bash
   npm install

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TokenMaster is ERC721 {
    uint256 public totalSupply;
    uint256 public totalOccasions;

    struct Occasion {
        uint256 id;
        uint256 cost;
        uint256 totalSeats;
        uint256 seatsTaken;
    }
    struct ResaleListing {
        uint256 tokenId;
        uint256 price;
        address seller;
    }

    // Mapping of occasionId to Occasion
    mapping(uint256 => Occasion) public occasions;

    // Mapping to track seat ownership
    mapping(uint256 => mapping(uint256 => address)) public seatsTaken;

    // Mapping to track if a user has already bought for an occasion
    mapping(uint256 => mapping(address => bool)) public hasBought;
    // tokenId => ResaleListing
    mapping(uint256 => ResaleListing) public resaleListings;


    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    // Create a new occasion
    function createOccasion(uint256 _cost, uint256 _totalSeats) public {
        require(_cost > 0, "Cost must be greater than 0");
        require(_totalSeats > 0, "Total seats must be greater than 0");

        totalOccasions++;
        occasions[totalOccasions] = Occasion({
            id: totalOccasions,
            cost: _cost,
            totalSeats: _totalSeats,
            seatsTaken: 0
        });
    }

        // Get a specific occasion by ID
    function getOccasionById(uint256 _id) public view returns (
        uint256 id,
        uint256 cost,
        uint256 totalSeats,
        uint256 seatsTakenCount
    ) {
        Occasion memory occ = occasions[_id];
        require(occ.id != 0, "Occasion does not exist");

        return (occ.id, occ.cost, occ.totalSeats, occ.seatsTaken);
    }
    // Get all occasions
    function getAllOccasions() public view returns (
        uint256[] memory ids,
        uint256[] memory costs,
        uint256[] memory totalSeatsList,
        uint256[] memory seatsTakenList
    ) {
        uint256 count = totalOccasions;
        ids = new uint256[](count);
        costs = new uint256[](count);
        totalSeatsList = new uint256[](count);
        seatsTakenList = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 occId = i + 1;
            Occasion memory occ = occasions[occId];

            ids[i] = occ.id;
            costs[i] = occ.cost;
            totalSeatsList[i] = occ.totalSeats;
            seatsTakenList[i] = occ.seatsTaken;
        }

        return (ids, costs, totalSeatsList, seatsTakenList);
    }

    function listTicketForResale(uint256 _tokenId, uint256 _price) public {
        require(ownerOf(_tokenId) == msg.sender, "Only ticket owner can list");
        require(_price > 0, "Price must be greater than zero");

        // Find original occasion price
        uint256 originalPrice = 0;
        for (uint256 i = 1; i <= totalOccasions; i++) {
            for (uint256 j = 0; j < occasions[i].seatsTaken; j++) {
                if ( _tokenId <= totalSupply && seatsTaken[i][j] == msg.sender) {
                    originalPrice = occasions[i].cost;
                    break;
                }
            }
            if (originalPrice > 0) break;
        }

        require(originalPrice > 0, "Original price not found");
        require(_price <= (originalPrice * 150) / 100, "Price exceeds 1.5x original");

        resaleListings[_tokenId] = ResaleListing({
            tokenId: _tokenId,
            price: _price,
            seller: msg.sender
        });
    }

    function buyResaleTicket(uint256 _tokenId) public payable {
        ResaleListing memory listing = resaleListings[_tokenId];
        require(listing.tokenId != 0, "Listing does not exist");
        require(msg.value >= listing.price, "Not enough ETH sent");

        // Remove listing before transfer to prevent reentrancy
        delete resaleListings[_tokenId];

        // Transfer ticket
        _transfer(listing.seller, msg.sender, _tokenId);

        // Pay seller
        payable(listing.seller).transfer(listing.price);

        // Refund excess
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
    }


    // Buy one or more tickets
    function buyTickets(uint256 _occasionId, uint256 _quantity) public payable {
        Occasion storage occ = occasions[_occasionId];
        require(occ.id != 0, "Occasion does not exist");
        require(_quantity > 0, "Must buy at least one ticket");
        require(occ.seatsTaken + _quantity <= occ.totalSeats, "Not enough tickets left");

        uint256 totalCost = occ.cost * _quantity;
        require(msg.value >= totalCost, "Insufficient payment");

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 seatNumber = occ.seatsTaken;
            occ.seatsTaken++;

            totalSupply++;
            _safeMint(msg.sender, totalSupply);
            seatsTaken[_occasionId][seatNumber] = msg.sender;
        }

        hasBought[_occasionId][msg.sender] = true;

        // Refund excess
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }
    function cancelAndRefundTicket(uint256 _tokenId) public {
        address owner = ownerOf(_tokenId);
        require(owner != address(0), "Invalid token owner");

        // Find the occasion and cost
        uint256 occasionCost = 0;
        for (uint256 i = 1; i <= totalOccasions; i++) {
            for (uint256 j = 0; j < occasions[i].seatsTaken; j++) {
                if (seatsTaken[i][j] == owner) {
                    occasionCost = occasions[i].cost;
                    seatsTaken[i][j] = address(0); // Clear seat assignment
                    break;
                }
            }
            if (occasionCost > 0) break;
        }

        require(occasionCost > 0, "Could not find original cost");

        // Refund 90% to the owner
        uint256 refundAmount = (occasionCost * 90) / 100;
        payable(owner).transfer(refundAmount);

        // Burn the token
        _burn(_tokenId);
    }

    function getSeatsTaken(uint256 _occasionId) public view returns (address[] memory) {
        Occasion storage occ = occasions[_occasionId];
        address[] memory seatOwners = new address[](occ.seatsTaken);

        for (uint256 i = 0; i < occ.seatsTaken; i++) {
            seatOwners[i] = seatsTaken[_occasionId][i];
        }

        return seatOwners;
    }

    receive() external payable {}

    function withdraw(address payable _to, uint256 _amount) public {
        require(_to != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= _amount, "Insufficient contract balance");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }
}
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "hardhat/console.sol";

/**
 * @title A Standing Order Contract
 * @author Joshua Adesanya
 * @notice This contract is for creating a standing order to automatate sending crypto to other addresses .
 */
contract ST {
    // Errors
    error Order__NotOwner();

    // State Variables
    uint256 private odcount;

    struct Order {
        uint256 id;
        string name;
        uint256 dofp;
        uint256 dolp;
        uint256 lastp;
        uint256 interval;
        uint256 amount;
        address recipient;
        bool status;
        address owner;
    }

    // Events
    event orderCreated(uint256 indexed id, string indexed name);

    // Mappings

    mapping(uint256 => Order) private idToOrder;

    // Modifiers
    modifier onlyOrderOwner(uint256 id) {
        if (idToOrder[id].owner != msg.sender) revert Order__NotOwner();
        _;
    }

    // Constructor

    constructor() {}

    // External Functions

    /*
     * @notice Create a Standing Order
     *  
     *  
     */
    function createOrder(
        string calldata name,
        uint256 amount,
        uint256 dofp,
        uint256 dolp,
        uint256 interval,
        address recipient
    ) external payable {
        idToOrder[odcount] = Order(odcount, name, dofp, dolp, 0, interval, amount, recipient, false, msg.sender);
        emit orderCreated(odcount, name);
        odcount++;
    }

    function pauseOrder() public {}

    function cancelOrder() public {}

    // start payment with dofp - Done
    // check interval
    // check order status
    // check day of last payment

    function payOrder() public {
        for (uint256 i = 0; i < odcount; i++) {
            if (idToOrder[i].status == false && block.timestamp <= idToOrder[i].dolp) {
                if (idToOrder[i].dofp <= block.timestamp && idToOrder[i].lastp == 0) {
                    // stop action
                    idToOrder[i].lastp = block.timestamp;
                    (bool success,) = (idToOrder[i].recipient).call{value: idToOrder[i].amount}("");
                    require(success, "Failed to send funds");
                } else if (
                    idToOrder[i].dofp < block.timestamp && idToOrder[i].lastp > 0
                        && (block.timestamp - idToOrder[i].lastp) >= idToOrder[i].interval
                ) {
                    idToOrder[i].lastp = block.timestamp;
                }
            }
        }
    }

    function runOrder() public {}

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    // Public Functions

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

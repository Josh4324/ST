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
    ) external {
        idToOrder[odcount] = Order(odcount, name, dofp, dolp, interval, amount, recipient, false, msg.sender);
        emit orderCreated(odcount, name);
        odcount++;
    }
}

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
    error Order__InsufficientAmount();

    // State Variables
    uint256 private odcount;
    uint256 private hiscount;

    struct Order {
        uint256 id;
        string name;
        uint256 order_amount;
        uint256 dofp;
        uint256 dolp;
        uint256 lastp;
        uint256 interval;
        uint256 amount;
        address recipient;
        bool status;
        address owner;
        uint256 amountPaid;
        bool or_status;
        bool deleted;
    }

    struct History {
        uint256 id;
        uint256 orderId;
        uint256 amount;
        address recipient;
        address owner;
    }

    // Events
    event orderCreated(uint256 indexed id, string indexed name);

    // Mappings

    mapping(uint256 => Order) private idToOrder;
    mapping(uint256 => History) private idToHistory;

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
        uint256 amount, // total amount
        uint256 order_amount,
        uint256 dofp, // number of seconds to the first payment
        uint256 dolp, // number of seconds to the last payment
        uint256 interval, // interval of payment (seconds)
        address recipient
    ) external payable {
        if (msg.value < amount) {
            revert Order__InsufficientAmount();
        }

        uint256 first_payment = block.timestamp + dofp;
        uint256 last_payment = block.timestamp + dolp;

        idToOrder[odcount] = Order(
            odcount,
            name,
            order_amount,
            first_payment,
            last_payment,
            0,
            interval,
            amount,
            recipient,
            false,
            msg.sender,
            0,
            false,
            false
        );
        emit orderCreated(odcount, name);
        odcount++;
    }

    function editOrder(
        uint256 id,
        uint256 order_amount,
        uint256 dolp, // number of seconds to the last payment
        uint256 interval // interval of payment (seconds)
    ) external onlyOrderOwner(id) {
        uint256 last_payment = block.timestamp + dolp;

        idToOrder[id].dolp = last_payment;
        idToOrder[id].order_amount = order_amount;
        idToOrder[id].interval = interval;
    }

    function pauseOrder(uint256[] calldata ids) public {
        for (uint256 i = 0; i < odcount; i++) {
            if (idToOrder[ids[i]].owner != msg.sender) {
                revert Order__NotOwner();
            }
            idToOrder[ids[i]].or_status = true;
        }
    }

    function startOrder(uint256[] calldata ids) public {
        for (uint256 i = 0; i < odcount; i++) {
            if (idToOrder[ids[i]].owner != msg.sender) {
                revert Order__NotOwner();
            }
            idToOrder[ids[i]].or_status = false;
        }
    }

    function deleteOrder(uint256 id) public onlyOrderOwner(id) {
        idToOrder[id].deleted = true;
    }

    // start payment with dofp - Done
    // check interval
    // check order status
    // check day of last payment
    // catch final payment

    function payOrder() public {
        for (uint256 i = 0; i < odcount; i++) {
            if (
                idToOrder[i].status == false && block.timestamp <= idToOrder[i].dolp && idToOrder[i].or_status == false
                    && idToOrder[i].deleted == false && idToOrder[i].amountPaid < idToOrder[i].amount
            ) {
                if (idToOrder[i].dofp <= block.timestamp && idToOrder[i].lastp == 0) {
                    // stop action
                    idToOrder[i].lastp = block.timestamp;
                    idToOrder[i].amountPaid = idToOrder[i].amountPaid + idToOrder[i].order_amount;

                    if (idToOrder[i].amountPaid == idToOrder[i].amount) {
                        idToOrder[i].status = true;
                    }

                    idToHistory[hiscount] = History(
                        hiscount, idToOrder[i].id, idToOrder[i].order_amount, idToOrder[i].recipient, idToOrder[i].owner
                    );
                    hiscount++;
                    (bool success,) = (idToOrder[i].recipient).call{value: idToOrder[i].order_amount}("");
                    require(success, "Failed to send funds");
                } else if (
                    idToOrder[i].dofp < block.timestamp && idToOrder[i].lastp > 0
                        && (block.timestamp - idToOrder[i].lastp) >= idToOrder[i].interval
                ) {
                    idToOrder[i].lastp = block.timestamp;
                    idToOrder[i].amountPaid = idToOrder[i].amountPaid + idToOrder[i].order_amount;

                    if (idToOrder[i].amountPaid == idToOrder[i].amount) {
                        idToOrder[i].status = true;
                    }

                    idToHistory[hiscount] = History(
                        hiscount, idToOrder[i].id, idToOrder[i].order_amount, idToOrder[i].recipient, idToOrder[i].owner
                    );
                    hiscount++;

                    (bool success,) = (idToOrder[i].recipient).call{value: idToOrder[i].order_amount}("");
                    require(success, "Failed to send funds");
                }
            }
        }
    }

    function getOrder(uint256 id) public view returns (Order memory) {
        return idToOrder[id];
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function withdraw() public {}

    // Public Functions

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

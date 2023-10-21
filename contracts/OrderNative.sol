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
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";

/**
 * @title A Standing Order Contract
 * @author Joshua Adesanya
 * @notice This contract is for creating a standing order to automatate sending crypto to other addresses .
 */
contract ST1 is AutomationCompatibleInterface {
    // Errors
    error Order__NotOwner();
    error Order__InsufficientAmount();

    // State Variables
    uint256 private odcount;
    uint256 private hiscount;
    address private s_keeperRegistryAddress;
    address private owner;

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
    event orderCreated(
        uint256 indexed id,
        string indexed name,
        uint256 order_amount,
        uint256 dofp,
        uint256 dolp,
        uint256 lastp,
        uint256 interval,
        uint256 amount,
        address recipient,
        bool status,
        address owner,
        uint256 amountPaid,
        bool or_status,
        bool deleted
    );

    event orderUpdated(uint256 id, uint256 order_amount, uint256 dolp, uint256 interval);

    event orderStatusUpdate(uint256 id, bool or_status);
    event orderDeleteUpdate(uint256 id, bool deleted);

    event Executed();

    // Mappings

    mapping(uint256 => Order) private idToOrder;
    mapping(uint256 => History) private idToHistory;

    // Modifiers
    modifier onlyOrderOwner(uint256 id) {
        if (idToOrder[id].owner != msg.sender) revert Order__NotOwner();
        _;
    }

    // Constructor

    /**
     * @param keeperRegistryAddress The address of the Chainlink Automation registry contract
     */
    constructor(address keeperRegistryAddress) {
        s_keeperRegistryAddress = keeperRegistryAddress;
        owner = msg.sender;
    }

    // External Functions

    /*
     * @notice Create a Standing Order
     *  
     *  
     */
    function createOrder(
        string calldata name,
        uint256 total_amount, // total amount
        uint256 order_amount,
        uint256 dofp, // number of seconds to the first payment
        uint256 dolp, // number of seconds to the last payment
        uint256 interval, // interval of payment (seconds)
        address recipient
    ) external payable {
        if (msg.value < total_amount) {
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
            total_amount,
            recipient,
            false,
            msg.sender,
            0,
            false,
            false
        );
        emit orderCreated(
            odcount,
            name,
            order_amount,
            first_payment,
            last_payment,
            0,
            interval,
            total_amount,
            recipient,
            false,
            msg.sender,
            0,
            false,
            false
        );
        odcount++;
    }

    /*
     * @notice Edit a Standing Order
     *  
     *  
     */
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

        emit orderUpdated(id, order_amount, last_payment, interval);
    }

    /*
     * @notice Pause a Standing Order
     *  
     *  
     */
    function pauseOrder(uint256[] calldata ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            if (idToOrder[ids[i]].owner != msg.sender) {
                revert Order__NotOwner();
            }
            idToOrder[ids[i]].or_status = true;
            emit orderStatusUpdate(i, true);
        }
    }

    /*
     * @notice Start a Standing Order
     *  
     *  
     */
    function startOrder(uint256[] calldata ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            if (idToOrder[ids[i]].owner != msg.sender) {
                revert Order__NotOwner();
            }
            idToOrder[ids[i]].or_status = false;
            emit orderStatusUpdate(i, false);
        }
    }

    /*
     * @notice Delete a Standing Order
     *  
     *  
     */
    function deleteOrder(uint256 id) public onlyOrderOwner(id) {
        idToOrder[id].deleted = true;
        emit orderDeleteUpdate(id, true);
    }

    /*
     * @notice Function that runs the payment
     *  
     *  
     */
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

    /*
     * @notice Function that checks if there is a pending payment
     *  
     *  
     */
    function payList() public view returns (Order[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < odcount; i++) {
            if (
                idToOrder[i].status == false && block.timestamp <= idToOrder[i].dolp && idToOrder[i].or_status == false
                    && idToOrder[i].deleted == false && idToOrder[i].amountPaid < idToOrder[i].amount
                    && (
                        idToOrder[i].dofp <= block.timestamp && idToOrder[i].lastp == 0
                            || idToOrder[i].dofp < block.timestamp && idToOrder[i].lastp > 0
                                && (block.timestamp - idToOrder[i].lastp) >= idToOrder[i].interval
                    )
            ) {
                itemCount += 1;
            }
        }

        Order[] memory items = new Order[](itemCount);

        for (uint256 i = 0; i < odcount; i++) {
            if (
                idToOrder[i].status == false && block.timestamp <= idToOrder[i].dolp && idToOrder[i].or_status == false
                    && idToOrder[i].deleted == false && idToOrder[i].amountPaid < idToOrder[i].amount
                    && (
                        idToOrder[i].dofp <= block.timestamp && idToOrder[i].lastp == 0
                            || idToOrder[i].dofp < block.timestamp && idToOrder[i].lastp > 0
                                && (block.timestamp - idToOrder[i].lastp) >= idToOrder[i].interval
                    )
            ) {
                uint256 currentId = i;

                Order storage currentItem = idToOrder[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @notice Check if there are orders that are due for payment with Chainlink Automation Network
     * @return upkeepNeeded signals if there are orders due
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        Order[] memory payListBool = payList();
        upkeepNeeded = (payListBool.length > 0);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @notice Called by Chainlink Automation Node to send funds for due orders
     */
    function performUpkeep(bytes calldata performData) external override {
        payOrder();
    }

    function getOrder(uint256 id) public view returns (Order memory) {
        return idToOrder[id];
    }

    function getOrders(address addr) public view returns (Order[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < odcount; i++) {
            if (idToOrder[i].deleted == false && idToOrder[i].owner == addr) {
                itemCount += 1;
            }
        }

        Order[] memory items = new Order[](itemCount);

        for (uint256 i = 0; i < odcount; i++) {
            if (idToOrder[i].deleted == false && idToOrder[i].owner == addr) {
                uint256 currentId = i;

                Order storage currentItem = idToOrder[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }

        uint256 length = items.length;
        Order[] memory reversedArray = new Order[](length);

        for (uint256 i = 0; i < length; i++) {
            reversedArray[i] = items[length - 1 - i];
        }
        return reversedArray;
    }

    function getTransactions(address addr) public view returns (History[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < hiscount; i++) {
            if (idToHistory[i].owner == addr) {
                itemCount += 1;
            }
        }

        History[] memory items = new History[](itemCount);

        for (uint256 i = 0; i < hiscount; i++) {
            if (idToHistory[i].owner == addr) {
                uint256 currentId = i;

                History storage currentItem = idToHistory[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }

        uint256 length = items.length;
        History[] memory reversedArray = new History[](length);

        for (uint256 i = 0; i < length; i++) {
            reversedArray[i] = items[length - 1 - i];
        }
        return reversedArray;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    // Public Functions

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

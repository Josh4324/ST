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
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";

/**
 * @title A Standing Order Contract
 * @author Joshua Adesanya
 * @notice This contract is for creating a standing order to automatate sending crypto to other addresses .
 */
contract ST is AutomationCompatibleInterface, AxelarExecutable {
    // Errors
    error Order__NotOwner();
    error Order__InsufficientAmount();

    // State Variables
    uint256 private odcount;
    uint256 private itcount;
    uint256 private hiscount;
    address private s_keeperRegistryAddress;
    address private owner;
    IAxelarGasService immutable gasService;

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

    struct InterChainOrder {
        uint256 id;
        string destinationChain;
        string destinationAddress;
        string symbol;
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
    event orderITCreated(uint256 indexed id, string indexed name);
    event Executed();

    // Mappings

    mapping(uint256 => Order) private idToOrder;
    mapping(uint256 => InterChainOrder) private idIOrder;
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
    constructor(address keeperRegistryAddress, address _gateway, address _gasReceiver) AxelarExecutable(_gateway) {
        s_keeperRegistryAddress = keeperRegistryAddress;
        owner = msg.sender;
        gasService = IAxelarGasService(_gasReceiver);
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
        emit orderCreated(odcount, name);
        odcount++;
    }

    function createOrderInterChain(
        string[] calldata para1, // name, destinationChain, destinationAddress, symbol
        uint256[] calldata para2, // total_amount, order_amount,dofp,dolp, interval
        address recipient
    ) external payable {
        uint256 first_payment = block.timestamp + para2[2];
        uint256 last_payment = block.timestamp + para2[3];

        InterChainOrder memory chainOrder;

        chainOrder.id = itcount;
        chainOrder.destinationChain = para1[1];
        chainOrder.destinationAddress = para1[2];
        chainOrder.symbol = para1[3];
        chainOrder.name = para1[0];
        chainOrder.order_amount = para2[1];
        chainOrder.dofp = first_payment;
        chainOrder.dolp = last_payment;
        chainOrder.interval = 0;
        chainOrder.amount = para2[0];
        chainOrder.recipient = recipient;
        chainOrder.status = false;
        chainOrder.owner = msg.sender;
        chainOrder.amountPaid = 0;
        chainOrder.or_status = false;
        chainOrder.deleted = false;

        idIOrder[itcount] = chainOrder;

        emit orderITCreated(itcount, para1[0]);
        itcount++;

        require(
            IERC20(0x2c852e740B62308c46DD29B982FBb650D063Bd07).transferFrom(msg.sender, address(this), para2[0]),
            "token transfer failed"
        );

        IERC20(0x2c852e740B62308c46DD29B982FBb650D063Bd07).approve(address(gateway), para2[1]);
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

    function payOrderInterChain() public {
        for (uint256 i = 0; i < itcount; i++) {
            if (
                idIOrder[i].status == false && block.timestamp <= idIOrder[i].dolp && idIOrder[i].or_status == false
                    && idIOrder[i].deleted == false && idIOrder[i].amountPaid < idIOrder[i].amount
            ) {
                if (idIOrder[i].dofp <= block.timestamp && idIOrder[i].lastp == 0) {
                    // stop action
                    idIOrder[i].lastp = block.timestamp;
                    idIOrder[i].amountPaid = idIOrder[i].amountPaid + idIOrder[i].order_amount;

                    if (idIOrder[i].amountPaid == idIOrder[i].amount) {
                        idIOrder[i].status = true;
                    }

                    idToHistory[hiscount] = History(
                        hiscount, idIOrder[i].id, idIOrder[i].order_amount, idIOrder[i].recipient, idIOrder[i].owner
                    );
                    hiscount++;

                    address tokenAddress = gateway.tokenAddresses(idIOrder[i].symbol);
                    IERC20(tokenAddress).approve(address(gateway), idIOrder[i].order_amount);

                    bytes memory payload = abi.encode(idIOrder[i].recipient);

                    gasService.payNativeGasForContractCallWithToken{value: 300000000000000000}(
                        address(this),
                        idIOrder[i].destinationChain,
                        idIOrder[i].destinationAddress,
                        payload,
                        idIOrder[i].symbol,
                        idIOrder[i].order_amount,
                        msg.sender
                    );

                    gateway.callContractWithToken(
                        idIOrder[i].destinationChain,
                        idIOrder[i].destinationAddress,
                        payload,
                        idIOrder[i].symbol,
                        idIOrder[i].order_amount
                    );
                } else if (
                    idIOrder[i].dofp < block.timestamp && idIOrder[i].lastp > 0
                        && (block.timestamp - idIOrder[i].lastp) >= idIOrder[i].interval
                ) {
                    idIOrder[i].lastp = block.timestamp;
                    idIOrder[i].amountPaid = idIOrder[i].amountPaid + idIOrder[i].order_amount;

                    if (idIOrder[i].amountPaid == idIOrder[i].amount) {
                        idIOrder[i].status = true;
                    }

                    idToHistory[hiscount] = History(
                        hiscount, idIOrder[i].id, idIOrder[i].order_amount, idIOrder[i].recipient, idIOrder[i].owner
                    );
                    hiscount++;

                    address tokenAddress = gateway.tokenAddresses(idIOrder[i].symbol);

                    IERC20(tokenAddress).approve(address(gateway), idIOrder[i].order_amount);

                    bytes memory payload = abi.encode(idIOrder[i].recipient);

                    gasService.payNativeGasForContractCallWithToken{value: 300000000000000000}(
                        address(this),
                        idIOrder[i].destinationChain,
                        idIOrder[i].destinationAddress,
                        payload,
                        idIOrder[i].symbol,
                        idIOrder[i].order_amount,
                        msg.sender
                    );

                    gateway.callContractWithToken(
                        idIOrder[i].destinationChain,
                        idIOrder[i].destinationAddress,
                        payload,
                        idIOrder[i].symbol,
                        idIOrder[i].order_amount
                    );
                }
            }
        }
    }

    function payList() public view returns (Order[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < odcount; i++) {
            if (
                idToOrder[i].status == false && block.timestamp <= idToOrder[i].dolp && idToOrder[i].or_status == false
                    && idToOrder[i].deleted == false && idToOrder[i].amountPaid < idToOrder[i].amount
            ) {
                itemCount += 1;
            }
        }

        Order[] memory items = new Order[](itemCount);

        for (uint256 i = 0; i < odcount; i++) {
            if (
                idToOrder[i].status == false && block.timestamp <= idToOrder[i].dolp && idToOrder[i].or_status == false
                    && idToOrder[i].deleted == false && idToOrder[i].amountPaid < idToOrder[i].amount
            ) {
                uint256 currentId = i;

                Order storage currentItem = idToOrder[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }
        return items;
    }

    function payList2() public view returns (InterChainOrder[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < itcount; i++) {
            if (
                idIOrder[i].status == false && block.timestamp <= idIOrder[i].dolp && idIOrder[i].or_status == false
                    && idIOrder[i].deleted == false && idIOrder[i].amountPaid < idIOrder[i].amount
            ) {
                itemCount += 1;
            }
        }

        InterChainOrder[] memory items = new InterChainOrder[](itemCount);

        for (uint256 i = 0; i < itcount; i++) {
            if (
                idIOrder[i].status == false && block.timestamp <= idIOrder[i].dolp && idIOrder[i].or_status == false
                    && idIOrder[i].deleted == false && idIOrder[i].amountPaid < idIOrder[i].amount
            ) {
                uint256 currentId = i;

                InterChainOrder storage currentItem = idIOrder[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @notice Get list of addresses that are underfunded and return payload compatible with Chainlink Automation Network
     * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoded list of addresses that need funds
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        Order[] memory payList1 = payList();
        InterChainOrder[] memory payList21 = payList2();
        upkeepNeeded = (payList1.length > 0 || payList21.length > 0);
        performData = abi.encode(payList1);
        return (upkeepNeeded, performData);
    }

    /**
     * @notice Called by Chainlink Automation Node to send funds to underfunded addresses
     * @param performData The abi encoded list of addresses to fund
     */
    function performUpkeep(bytes calldata performData) external override {
        payOrder();
        payOrderInterChain();
    }

    /*  function getOrder(uint256 id) public view returns (Order memory) {
        return idToOrder[id];
    } */

    function getOrder2(uint256 id) public view returns (InterChainOrder memory) {
        return idIOrder[id];
    }

    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        address recipient = abi.decode(payload, (address));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);

        IERC20(tokenAddress).transfer(recipient, amount);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function withdraw() public {
        (bool success,) = (owner).call{value: address(this).balance}("");
        require(success, "Failed to send funds");
    }

    // Public Functions

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

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
contract ST2 is AutomationCompatibleInterface, AxelarExecutable {
    // Errors
    error Order__NotOwner();
    error Order__InsufficientAmount();

    // State Variables
    uint256 private itcount;
    uint256 private hiscount;
    address private s_keeperRegistryAddress;
    address private owner;
    IAxelarGasService immutable gasService;

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
        string dchain;
    }

    // Events
    event orderCreated(
        uint256 indexed id,
        string destinationChain,
        string indexed name,
        uint256 order_amount,
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

    mapping(uint256 => InterChainOrder) private idIOrder;
    mapping(uint256 => History) private idToHistory;

    // Modifiers
    modifier onlyOrderOwner(uint256 id) {
        if (idIOrder[id].owner != msg.sender) revert Order__NotOwner();
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
     * @notice Create a Standing Order For Interchain Transfer
     *  
     *  
     */
    function createOrderInterChain(
        string[] calldata para1, // name, destinationChain, destinationAddress, symbol
        uint256[] calldata para2, // total_amount, order_amount,dofp,dolp, interval
        address recipient
    ) external payable {
        idIOrder[itcount] = InterChainOrder(
            itcount,
            para1[1],
            para1[2],
            para1[3],
            para1[0],
            para2[1],
            block.timestamp + para2[2],
            block.timestamp + para2[3],
            0,
            para2[4],
            para2[0],
            recipient,
            false,
            msg.sender,
            0,
            false,
            false
        );

        emit orderCreated(
            itcount, para1[1], para1[0], para2[1], para2[4], para2[0], recipient, false, msg.sender, 0, false, false
        );
        itcount++;

        require(
            IERC20(0x57F1c63497AEe0bE305B8852b354CEc793da43bB).transferFrom(msg.sender, address(this), para2[0]),
            "token transfer failed"
        );
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

        idIOrder[id].dolp = last_payment;
        idIOrder[id].order_amount = order_amount;
        idIOrder[id].interval = interval;
        emit orderUpdated(id, order_amount, last_payment, interval);
    }

    /*
     * @notice Pause a Standing Order
     *  
     *  
     */
    function pauseOrder(uint256[] calldata ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            if (idIOrder[ids[i]].owner != msg.sender) {
                revert Order__NotOwner();
            }
            idIOrder[ids[i]].or_status = true;
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
            if (idIOrder[ids[i]].owner != msg.sender) {
                revert Order__NotOwner();
            }
            idIOrder[ids[i]].or_status = false;
            emit orderStatusUpdate(i, false);
        }
    }

    /*
     * @notice Delete a Standing Order
     *  
     *  
     */
    function deleteOrder(uint256 id) public onlyOrderOwner(id) {
        idIOrder[id].deleted = true;
        emit orderDeleteUpdate(id, true);
    }

    /*
     * @notice Function that runs the interchain payment
     *  
     *  
     */
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
                        hiscount,
                        idIOrder[i].id,
                        idIOrder[i].order_amount,
                        idIOrder[i].recipient,
                        idIOrder[i].owner,
                        idIOrder[i].destinationChain
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
                        hiscount,
                        idIOrder[i].id,
                        idIOrder[i].order_amount,
                        idIOrder[i].recipient,
                        idIOrder[i].owner,
                        idIOrder[i].destinationChain
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

    /*
     * @notice Function that checks if there is a pending payment
     *  
     *  
     */
    function payList() public view returns (InterChainOrder[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < itcount; i++) {
            if (
                idIOrder[i].status == false && block.timestamp <= idIOrder[i].dolp && idIOrder[i].or_status == false
                    && idIOrder[i].deleted == false && idIOrder[i].amountPaid < idIOrder[i].amount
                    && (
                        idIOrder[i].dofp <= block.timestamp && idIOrder[i].lastp == 0
                            || idIOrder[i].dofp < block.timestamp && idIOrder[i].lastp > 0
                                && (block.timestamp - idIOrder[i].lastp) >= idIOrder[i].interval
                    )
            ) {
                itemCount += 1;
            }
        }

        InterChainOrder[] memory items = new InterChainOrder[](itemCount);

        for (uint256 i = 0; i < itcount; i++) {
            if (
                idIOrder[i].status == false && block.timestamp <= idIOrder[i].dolp && idIOrder[i].or_status == false
                    && idIOrder[i].deleted == false && idIOrder[i].amountPaid < idIOrder[i].amount
                    && (
                        idIOrder[i].dofp <= block.timestamp && idIOrder[i].lastp == 0
                            || idIOrder[i].dofp < block.timestamp && idIOrder[i].lastp > 0
                                && (block.timestamp - idIOrder[i].lastp) >= idIOrder[i].interval
                    )
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
     * @notice Check if there are orders that are due for payment with Chainlink Automation Network
     * @return upkeepNeeded signals if there are orders due
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        InterChainOrder[] memory payListBool = payList();
        upkeepNeeded = (payListBool.length > 0);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @notice Called by Chainlink Automation Node to send funds for due orders
     */
    function performUpkeep(bytes calldata performData) external override {
        payOrderInterChain();
    }

    function getOrder(uint256 id) public view returns (InterChainOrder memory) {
        return idIOrder[id];
    }

    function getOrders(address addr) public view returns (InterChainOrder[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < itcount; i++) {
            if (idIOrder[i].deleted == false && idIOrder[i].owner == addr) {
                itemCount += 1;
            }
        }

        InterChainOrder[] memory items = new InterChainOrder[](itemCount);

        for (uint256 i = 0; i < itcount; i++) {
            if (idIOrder[i].deleted == false && idIOrder[i].owner == addr) {
                uint256 currentId = i;

                InterChainOrder storage currentItem = idIOrder[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }

        uint256 length = items.length;
        InterChainOrder[] memory reversedArray = new InterChainOrder[](length);

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

    // Public Functions

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

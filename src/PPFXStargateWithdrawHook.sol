// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import {IPPFX} from "./IPPFX.sol";
import {IStargate} from "./IStargate.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PPFXStargateWithdrawHook is Context, ReentrancyGuard {
    using OptionsBuilder for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for ERC20;

    event NewOperator(address indexed newOperatorAddress);
    event OperatorRemoved(address indexed operatorAddr);
    event NewTreasury(address indexed newTreasuryAddress);
    event NewAdmin(address indexed newAdminAddress);
    event TransferAdmin(address indexed newAdminAddress);

    uint256 constant public MAX_OPERATORS = 10;

    IStargate public immutable stargate;
    IPPFX public immutable ppfx;

    address public treasury;
    address public admin;
    address private pendingAdmin;
    EnumerableSet.AddressSet private operators;

    mapping(uint256 => uint256) public dstChainUsdtDecimal;

    /**
     * @dev Throws if called by any account other than the Admin
     */
    modifier onlyAdmin {
        require(_msgSender() == admin, "Caller not admin");
        _;
    }

    /**
     * @dev Throws if called by any account other than the Operator
     */
    modifier onlyOperator {
        require(operators.contains(_msgSender()), "Caller not operator");
        _;
    }

    constructor(
        IPPFX _ppfx,
        address _admin,
        address _treasury,
        address _stargate // 0x1502FA4be69d526124D453619276FacCab275d3D
    ) {
        ppfx = _ppfx;
        stargate = IStargate(_stargate);
        _updateAdmin(_admin);
        _updateTreasury(_treasury);
        ERC20(ppfx.usdt()).approve(address(stargate), type(uint256).max);
    }
    
    /****************************
     * Operators only functions *
     ****************************/

    /**
     * @dev Withdraw for User
     * @param fromUser Target user to withdraw from
     * @param amount Amount to withdraw
     * @param data The data & signature signed by user to delegate this contract to withdraw for the user
     * 
     * Can only be called by operator
     */
    function withdrawForUser(address fromUser, uint256 amount, bytes calldata data) external onlyOperator {
        ppfx.withdrawForUser(address(this), fromUser, amount, data);
    }
    
    /**
     * @dev Claim pending withdrawal for user
     * @param fromUser Target user to claim pending withdrawal from
     * @param data The data & signature signed by user to delegate this contract to claim for the user
     * @param dstEndpointID The destination chain LayerZero endpoint id
     * @param fee Fee deduct from user withdrawal and send to treasury, can be zero
     * 
     * Can only be called by operator
     */
    function claimWithdrawalForUser(address fromUser, bytes calldata data, uint32 dstEndpointID, uint256 dstUsdtDecimal, uint256 fee) external payable onlyOperator {
        // Query .usdt() everytime to prevent inconsistent usdt if PPFX update USDT address
        ERC20 usdt = ERC20(ppfx.usdt());
        uint256 beforeClaimBal = usdt.balanceOf(address(this));
        ppfx.claimPendingWithdrawalForUser(address(this), fromUser, data);
        uint256 afterClaimBal = usdt.balanceOf(address(this));

        // Calculate claimed amount & deduct fee & send fee to treasury
        uint256 claimed = afterClaimBal - beforeClaimBal;
        
        if (fee > 0) {
            // Not allow claimed == fee, that means bridging 0 usdt.
            require(claimed > fee, "PPFXStargateWithdrawHook: Insufficient claimed balance to cover the fee");
            usdt.safeTransfer(treasury, fee);
        }
        
        uint256 sendAmount = claimed - fee;
        uint256 convertedSendAmount = sendAmount * (1 ** dstUsdtDecimal / 1 ** usdt.decimals());
        require(convertedSendAmount > 0, "PPFXStargateWithdrawHook: Converted amount is lower or equals to 0");

        // TODO: Send gas limit as function args / see if there is a way to estimate it
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam(
            dstEndpointID,
            bytes32(uint256(uint160(fromUser))), // Recipient address
            sendAmount, // Send amount
            sendAmount, // Minimum send amount
            options,
            "",
            ""
        );
        
        MessagingFee memory stargateFee = stargate.quoteSend(sendParam, false);
        require(msg.value >= stargateFee.nativeFee, "PPFXStargateWithdrawHook: Insufficient msg.value to bridge token");

        // This contract address is the refund address
        stargate.sendToken{value: stargateFee.nativeFee}(sendParam, stargateFee, address(this));
        uint256 remaining = msg.value - stargateFee.nativeFee;
        if (remaining > 0) {
            bool success = payable(msg.sender).send(remaining);
            require(success, "PPFXStargateWithdrawHook: Failed to refund fee");
        }
    }

    /************************
     * Admin only functions *
     ************************/

    /**
     * @dev Accept admin role
     * Emits a {NewAdmin} event.
     *     
     */
     function acceptAdmin() external {
        require(pendingAdmin != address(0), "Admin address can not be zero");
        require(_msgSender() == pendingAdmin, "Caller not pendingAdmin");
        _updateAdmin(pendingAdmin);
        pendingAdmin = address(0);
     }

    /**
     * @dev Update Admin account.
     * @param adminAddr The new admin address.     
     * Emits a {TransferAdmin} event.
     * 
     * Requirements:
     * - `adminAddr` cannot be the zero address.
     */
    function transferAdmin(address adminAddr) external onlyAdmin() {
        require(adminAddr != address(0), "Admin address can not be zero");
        _transferAdmin(adminAddr);
    }

    /**
     * @dev Update Treasury account.
     * @param treasuryAddr The new treasury address.
     *
     * Emits a {NewTreasury} event.
     *
     * Requirements:
     * - `treasuryAddr` cannot be the zero address.
     */
    function updateTreasury(address treasuryAddr) external onlyAdmin {
        require(treasuryAddr != address(0), "Treasury address can not be zero");
        _updateTreasury(treasuryAddr);
    }

    /**
     * @dev Add Operator account.
     * @param operatorAddr The new operator address.
     *
     * Emits a {NewOperator} event.
     *
     * Requirements:
     * - `operatorAddr` cannot be the zero address.
     * - `operatorAddr` must not exists in the operators array.
     */
    function addOperator(address operatorAddr) external onlyAdmin {
        require(operatorAddr != address(0), "Operator address can not be zero");
        require(!operators.contains(operatorAddr), "Operator already exists");
        require(operators.length() <= MAX_OPERATORS, "Too many operators");
        _addOperator(operatorAddr);
    }

     /**
     * @dev Remove Operator account.
     * @param operatorAddr The target operator address.
     *
     * Emits a {OperatorRemoved} event.
     *
     * Requirements:
     * - `operatorAddr` cannot be the zero address.
     * - `operatorAddr` must exists in the operators array.
     */
    function removeOperator(address operatorAddr) external onlyAdmin {
        require(operatorAddr != address(0), "Operator address can not be zero");
        require(operators.contains(operatorAddr), "Operator does not exists");
        _removeOperator(operatorAddr);
    }

    /**
     * @dev Remove All Operator accounts.
     *
     * Emits {OperatorRemoved} event for every deleted operator.
     *
     */
    function removeAllOperator() external onlyAdmin {
        require(operators.length() > 0, "No operator found");
        _removeAllOperator();
    }

    /**********************
     * Internal functions *
     **********************/

    function _removeAllOperator() internal {
        address[] memory operatorList = operators.values();
        uint operatorLen = operatorList.length;
        for (uint i = 0; i < operatorLen; i++) {
            address operatorToBeRemoved = operatorList[i];
            operators.remove(operatorToBeRemoved);
            emit OperatorRemoved(operatorToBeRemoved);
        }
    }

    function _removeOperator(address operatorAddr) internal {
        operators.remove(operatorAddr);
        emit OperatorRemoved(operatorAddr);
    }

    function _addOperator(address operatorAddr) internal {
        operators.add(operatorAddr);
        emit NewOperator(operatorAddr);
    }

    function _transferAdmin(address adminAddr) internal {
        pendingAdmin = adminAddr;
        emit TransferAdmin(adminAddr);
    }

    function _updateAdmin(address adminAddr) internal {
        admin = adminAddr;
        emit NewAdmin(adminAddr);
    }

    function _updateTreasury(address treasuryAddr) internal {
        treasury = treasuryAddr;
        emit NewTreasury(treasuryAddr);
    }
}
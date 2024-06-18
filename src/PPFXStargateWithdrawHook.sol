// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import {IPPFX} from "./IPPFX.sol";
import {IStargate, Ticket} from "./IStargate.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SendParam, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract PPFXStargateWithdrawHook is Ownable2Step, ReentrancyGuard {
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
        address _stargate
    ) {
        ppfx = _ppfx;
        stargate = IStargate(_stargate);
        _transferOwnership(_admin);
        _updateTreasury(_treasury);
    }

    /**
     * @dev Get all operator address.
     */
    function getAllOperators() external view returns (address[] memory) {
        return operators.values();
    }

    /**
     * @dev Check if target address is operator.
     */
    function isOperator(address target) external view returns (bool) {
        return operators.contains(target);
    }
    
    /****************************
     * Operators only functions *
     ****************************/

    /**
     * @dev Withdraw for User
     * @param delegateData Delegate Data to withdraw from a user, including the signature
     * 
     * Can only be called by operator
     */
    function withdrawForUser(IPPFX.DelegateData calldata delegateData) external onlyOperator {
        ppfx.withdrawForUser(address(this), delegateData.from, delegateData.amount, delegateData);
    }
    
    /**
     * @dev Claim pending withdrawal for user
     * @param delegateData Delegate Data to claim pending withdrawal from a user, including the signature
     * @param dstEndpointID The destination chain LayerZero endpoint id
     * @param fee Fee deduct from user withdrawal and send to treasury, can be zero
     * 
     * Can only be called by operator
     */
    function claimWithdrawalForUser(IPPFX.DelegateData calldata delegateData, uint32 dstEndpointID, uint256 slippage, uint256 fee) external payable onlyOperator {
        address fromUser = delegateData.from;
        // Query .usdt() everytime to prevent inconsistent usdt if PPFX update USDT address
        ERC20 usdt = ERC20(ppfx.usdt());
        uint256 beforeClaimBal = usdt.balanceOf(address(this));
        ppfx.claimPendingWithdrawalForUser(address(this), fromUser, delegateData);
        uint256 afterClaimBal = usdt.balanceOf(address(this));

        // Calculate claimed amount & deduct fee & send fee to treasury
        uint256 claimed = afterClaimBal - beforeClaimBal;
        
        // Expecting `claimed` to be greater than 0,
        // Not allow claimed == fee, that means bridging 0 usdt.
        // This case works even given fee is 0 & non zero
        require(claimed > fee, "PPFXStargateWithdrawHook: Insufficient claimed balance to cover the fee");

        // Only transfer fee to treasury if fee is greater than 0
        if (fee > 0) {
            usdt.safeTransfer(treasury, fee);
        }

        uint256 sendAmount = claimed - fee;

        // Expecting slippage to be at least 6, 6bps
        uint256 minSendAmount = sendAmount * (10000 - slippage) / 10000;
    
        SendParam memory sendParam = SendParam(
            dstEndpointID,
            bytes32(uint256(uint160(fromUser))), // Recipient address
            sendAmount, // Send amount
            minSendAmount, // Minimum send amount
            "", // No extra options needed, not doing lzReceive / lzCompose etc...
            "", // No Composed Message needed since we are transfering to user address
            ""
        );
        
        MessagingFee memory stargateFee = stargate.quoteSend(sendParam, false);
        // Make sure the msg.value is enough to cover the stargate fee
        require(msg.value >= stargateFee.nativeFee, "PPFXStargateWithdrawHook: Insufficient msg.value to bridge token");

        // Increase allowance before calling startgate.sendToken()
        usdt.safeIncreaseAllowance(address(stargate), sendAmount);
        
        // Refund to treasury if anything happens
        // Not refunding to this contract address because we are not expecting this contract to be holding any funds
        stargate.sendToken{value: stargateFee.nativeFee}(sendParam, stargateFee, treasury);
        uint256 remaining = msg.value - stargateFee.nativeFee;
        if (remaining > 0) {
            // Refund rest of the ETH if there is remaining after paying stargate fee
            bool success = msg.sender.call{ value: remaining}("");
            require(success, "PPFXStargateWithdrawHook: Failed to refund fee");
        }
    }

    /*******************************
     * Owner(Admin) only functions *
     *******************************/

    /**
     * @dev Sweep ERC20 Token
     * Withdraw hook shouldn't be holding any tokens,
     * sweepToken() in case of token stuck in the withdraw hook
     *
     * Requirements:
     * - `sender` must be owner (admin)
     */
    function sweepToken(ERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No Token to sweep");
        token.transfer(admin, balance);
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
    function updateTreasury(address treasuryAddr) external onlyOwner {
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
    function addOperator(address operatorAddr) external onlyOwner {
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
    function removeOperator(address operatorAddr) external onlyOwner {
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
    function removeAllOperator() external onlyOwner {
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

    function _updateTreasury(address treasuryAddr) internal {
        treasury = treasuryAddr;
        emit NewTreasury(treasuryAddr);
    }
}
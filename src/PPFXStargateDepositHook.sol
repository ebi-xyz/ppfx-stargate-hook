// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import {IOAppComposer} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPPFX} from "./IPPFX.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PPFXStargateDepositHook is Ownable, IOAppComposer {
    using SafeERC20 for IERC20;

    IPPFX public immutable ppfx;
    address public immutable lzEndpoint;
    address public immutable stargate;

    /// @notice Constructs the PPFXStargateDepositHook contract.
    /// @dev Initializes the contract.
    /// @param _ppfx The address of the PPFX Contract
    /// @param _lzEndpoint LayerZero Endpoint address
    /// @param _stargate The address of the Stargate contract
    /// @param _admin Admin address
    constructor(
        address _ppfx,
        address _lzEndpoint,
        address _stargate,
        address _admin
    ) {
        ppfx = IPPFX(_ppfx);
        lzEndpoint = _lzEndpoint;
        stargate = _stargate;
        _transferOwnership(_admin);
    }

    /// @notice Handles incoming composed messages from LayerZero.
    /// @dev Decodes the message payload to perform a token swap.
    ///      This method expects the encoded compose message to contain the swap amount and recipient address.
    /// @param _oApp The address of the originating OApp.
    /// @param /*_guid*/ The globally unique identifier of the message (unused in this mock).
    /// @param _message The encoded message content in the format of the OFTComposeMsgCodec.
    /// @param /*Executor*/ Executor address (unused in this mock).
    /// @param /*Executor Data*/ Additional data for checking for a specific executor (unused in this mock).
    function lzCompose(
        address _oApp,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*Executor*/,
        bytes calldata /*Executor Data*/
    ) external payable override {
        require(msg.sender == lzEndpoint, "PPFXStargateDepositHook: Not LayerZero Endpoint");
        require(_oApp == stargate, "PPFXStargateDepositHook: Not Stargate Contract");
        require(msg.value == 0, "PPFXStargateDepositHook: msg.value must be zero to prevent native token stuck");
        // Get the authenticated amount from stargate message
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        // Get the authenticated sender from stargate message, expecting the sender to be the receiver in PPFX
        address sender = OFTComposeMsgCodec.bytes32ToAddress(OFTComposeMsgCodec.composeFrom(_message));
        // Increase usdt allowance to PPFX before depositing
        IERC20(ppfx.usdt()).safeIncreaseAllowance(address(ppfx), amountLD);

        ppfx.depositForUser(sender, amountLD);
    }

    /************************
     * Owner only functions *
     ************************/

    /**
     * @dev Sweep ERC20 Token
     * Deposit hook shouldn't be holding any tokens,
     * sweepToken() in case of token stuck in the deposit hook
     *
     * Requirements:
     * - `sender` must be the owner
     */
    function sweepToken(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No Token to sweep");
        token.safeTransfer(owner(), balance);
    }
}
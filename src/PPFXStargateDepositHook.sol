// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IOAppComposer} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import {IPPFX} from "./IPPFX.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";


contract PPFXStargateDepositHook is IOAppComposer, Ownable, ReentrancyGuard {
    IPPFX public ppfx;
    address public immutable endpoint;
    address public immutable stargate;

    /// @notice Constructs the PPFXStargateDepositHook contract.
    /// @dev Initializes the contract.
    /// @param _ppfx The address of the PPFX Contract
    /// @param _endpoint LayerZero Endpoint address
    /// @param _stargate The address of the Stargate contract
    constructor(address _ppfx, address _endpoint, address _stargate) {
        ppfx = IPPFX(_ppfx);
        endpoint = _endpoint;
        stargate = _stargate;
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
        require(_oApp == stargate, "!Stargate");
        require(msg.sender == endpoint, "!endpoint");

        // Extract the composed message from the delivered message using the MsgCodec
        bytes memory _composeMsgContent = OFTComposeMsgCodec.composeMsg(_message);
        // Decode the composed message, in this case, the uint256 amount and address receiver for the deposit
        (uint256 _amountToDeposit, address _receiver) = abi.decode(_composeMsgContent, (uint256, address));

        ppfx.depositForUser(_receiver, _amountToDeposit);
    }

    function updatePPFX(address _newPPFX) external onlyOwner {
        ppfx = IPPFX(_newPPFX);
    }
}
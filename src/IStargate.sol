// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

enum StargateType {
    Pool,
    OFT
}

struct Ticket {
    uint56 ticketId;
    bytes passenger;
}

struct RideBusOptions {
    uint128 extraFare;
    uint128 nativeDropAmount;
    uint128 lzComposeGas;
    uint128 lzComposeValue;
}

interface IStargate is IOFT {
    /// @dev This function is same as `send` in OFT interface but returns the passenger data if in the bus ride mode,
    /// which allows the caller to ride and drive the bus in the same transaction.
    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket);

    /// @dev Quote the extra bus fare and return the ride bus options details.
    function quoteRideBusOptions(
        uint32 _dstEid,
        bytes calldata _options,
        uint256 _composeMsgSize
    ) external view returns (RideBusOptions memory rideBusOptions);

    function stargateType() external pure returns (StargateType);
}

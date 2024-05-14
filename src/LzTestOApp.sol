// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin, MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

contract LzTestOApp is OApp {

    bool public l1Sent = false;
    bool public l2Received = false;



    bytes32 public l2ReceivedGuid;
    string public l2ReceivedData;
    address public l2ReceivedExecutor;
    bytes public l2ReceivedExtraData;
    Origin public l2ReceivedOrigin;
   //  bytes public testingOptions = 0x0003010011010000000000000000000000000000ea60;

    constructor(address _endpoint) OApp(_endpoint, msg.sender) {}

    // Sends a message from the source to destination chain.
    function send(uint32 _dstEid, string memory _message, bytes memory _options) external payable {
        bytes memory _payload = abi.encode(_message); // Encodes message as bytes.
        _lzSend(
            _dstEid, // Destination chain's endpoint ID.
            _payload, // Encoded message payload being sent.
            _options, // Message execution options (e.g., gas to use on destination).
            MessagingFee(msg.value, 0), // Fee struct containing native gas and ZRO token.
            payable(msg.sender) // The refund address in case the send call reverts.
        );
        l1Sent = true;
    }

    function _lzReceive(
        Origin calldata _origin, // struct containing info about the message sender
        bytes32 _guid, // global packet identifier
        bytes calldata payload, // encoded message payload being received
        address _executor, // the Executor address.
        bytes calldata _extraData // arbitrary data appended by the Executor
    ) internal override {
        string memory data = abi.decode(payload, (string)); // your logic here

        // struct Origin {
        //     uint32 srcEid;
        //     bytes32 sender;
        //     uint64 nonce;
        // }

        l2Received = true;
        l2ReceivedData = data;
        l2ReceivedOrigin = _origin;
        l2ReceivedGuid = _guid;
        l2ReceivedExecutor = _executor;
        l2ReceivedExtraData = _extraData;
    }

    /// @notice Estimates the gas associated with sending a message.
    /// @param _dstEid The endpoint ID of the destination chain.
    /// @param _message The message to be sent.
    /// @param _options The message execution options (e.g. gas to use on destination).
    /// @return nativeFee Estimated gas fee in native gas.
    /// @return lzTokenFee Estimated gas fee in ZRO token.
    function estimateFee(
        uint32 _dstEid,
        string memory _message,
        bytes calldata _options
    ) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        bytes memory _payload = abi.encode(_message);
        MessagingFee memory fee = _quote(_dstEid, _payload, _options, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }
}
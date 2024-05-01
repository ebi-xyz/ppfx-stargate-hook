// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IPPFX} from "./IPPFX.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IPPFXStargateHook} from "./IPPFXStargateHook.sol";
import {ILayerZeroReceiver} from "@layerzerolabs/contracts/interfaces/ILayerZeroReceiver.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/contracts/interfaces/ILayerZeroEndpoint.sol";


contract PPFXStargateHook is IPPFXStargateHook, ILayerZeroReceiver, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 private constant VALID_DATA_OFFSET = 20;
    uint256 private constant SIGNATURE_OFFSET = 180;
    
    address public authorized;
    IPPFX public ppfx;

    ILayerZeroEndpoint public immutable lzEndpoint;
    mapping(uint16 => bytes) public trustedRemoteLookup;

    modifier onlyAuthorized() {
        require(_msgSender() == authorized, "Not authorized");
        _;
    }

    constructor(
        IPPFX _ppfx,
        address _authorized,
        address _endpoint
    ) Ownable(_msgSender()) {
        ppfx = _ppfx;
        authorized = _authorized;
        lzEndpoint = ILayerZeroEndpoint(_endpoint);
    }

    /***********************
     * LayerZero functions *
     ***********************/

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public virtual override {
        // lzReceive must be called by the endpoint for security
        require(_msgSender() == address(lzEndpoint), "PPFXStargateHook: invalid endpoint caller");

        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
        // if will still block the message pathway from (srcChainId, srcAddress). should not receive message from untrusted remote.
        require(
            _srcAddress.length == trustedRemote.length && trustedRemote.length > 0 && keccak256(_srcAddress) == keccak256(trustedRemote),
            "PPFXStargateHook: invalid source sending contract"
        );

        // TODO: Handle data here, decide what the payload will be
    }

    /************************
     * Owner only functions *
     ************************/

    // _path = abi.encodePacked(remoteAddress, localAddress)
    // this function set the trusted path for the cross-chain communication
    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external onlyOwner {
        trustedRemoteLookup[_remoteChainId] = _path;
        emit SetTrustedRemote(_remoteChainId, _path);
    }

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external onlyOwner {
        trustedRemoteLookup[_remoteChainId] = abi.encodePacked(_remoteAddress, address(this));
        emit SetTrustedRemoteAddress(_remoteChainId, _remoteAddress);
    }

    /*************************************************
     * Functions for signing & validating signatures *
     *************************************************/

    function getHash(
        bytes4 selector, // deposit / withdraw / claim withdraw method id
        address user,
        uint256 amount,
        uint48 validAfter,
        uint48 validUntil
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(selector, block.chainid, user, amount, validAfter, validUntil)
        );
    }

    function validate(bytes calldata data) public view returns (bool){
         (
            bytes4 selector,
            address user,
            uint256 amount,
            uint48 validAfter,
            uint48 validUntil,
            bytes calldata signature
        ) = parseData(data);
        // solhint-disable-next-line reason-string
        require(
            signature.length == 64 || signature.length == 65,
            "PPFXStargateHook: invalid signature length in data"
        );

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(getHash(selector, user, amount, validAfter, validUntil));

        return user == ECDSA.recover(hash, signature);
    }

    function parseData(bytes calldata data) 
        public
        pure
        returns (
            bytes4 selector,
            address user,
            uint256 amount,
            uint48 validAfter,
            uint48 validUntil,
            bytes calldata signature
        )
    {
        (selector, user, amount, validAfter, validUntil) = abi.decode(
            data[VALID_DATA_OFFSET:SIGNATURE_OFFSET],
            (bytes4, address, uint256, uint48, uint48)
        );
        signature = data[SIGNATURE_OFFSET:];
    }
}
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IPPFX} from "./IPPFX.sol";
import {IStargate} from "./IStargate.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract PPFXStargateHook is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using OptionsBuilder for bytes;

    uint256 private constant VALID_DATA_OFFSET = 20;
    uint256 private constant SIGNATURE_OFFSET = 180;

    bytes4 public constant WITHDRAW_SELECTOR = bytes4(keccak256("withdrawForUser(bytes)"));
    bytes4 public constant CLAIM_SELECTOR = bytes4(keccak256("claimWithdrawalForUser(bytes)"));
    
    IStargate public immutable stargate;

    IPPFX public ppfx;
    address public authorized;
    mapping(address => uint256) public userNonce;

    modifier onlyAuthorized() {
        require(_msgSender() == authorized, "Not authorized");
        _;
    }

    constructor(
        IPPFX _ppfx,
        address _authorized,
        address _stargate
    ) {
        ppfx = _ppfx;
        authorized = _authorized;
        stargate = IStargate(_stargate);
    }
    
    /************************
     * Authorized only functions *
     ************************/

    function withdrawForUser(bytes calldata data) external onlyAuthorized {
        (bool valid, bytes4 methodID, address user, uint256 amount) = validate(data);
        require(valid, "Invalid data");
        require(methodID == WITHDRAW_SELECTOR, "Incorrect methodID");
        ppfx.withdrawForUser(user, amount);
        userNonce[user] += 1;
    }

    function claimWithdrawalForUser(bytes calldata data, uint32 endpointID) external onlyAuthorized {
        (bool valid, bytes4 methodID, address user, uint256 amount) = validate(data);
        require(valid, "Invalid data");
        require(methodID == CLAIM_SELECTOR, "Incorrect methodID");
        ppfx.claimPendingWithdrawalForUser(user);
        userNonce[user] += 1;

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam(
            endpointID,
            bytes32(uint256(uint160(user))),
            amount,
            amount,
            options,
            "",
            ""
        );
        
        MessagingFee memory fee = stargate.quoteSend(sendParam, false);
        stargate.sendToken{value: fee.nativeFee}(sendParam, fee, user);
    }

    /*************************************************
     * Functions for signing & validating signatures *
     *************************************************/

    function getHash(
        address user,
        uint256 amount,
        uint256 nonce,
        bytes4 methodID,
        uint48 validAt,
        uint48 validUntil
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(user, nonce, block.chainid, methodID, amount, validAt, validUntil)
        );
    }


    function validate(bytes calldata data) public view returns (bool, bytes4, address, uint256){
         (
            address user,
            uint256 amount,
            uint256 nonce,
            bytes4 methodID,
            uint48 validAt,
            uint48 validUntil,
            bytes calldata signature
        ) = parseData(data);
        // solhint-disable-next-line reason-string
        require(
            signature.length == 64 || signature.length == 65,
            "PPFXStargateHook: invalid signature length in data"
        );

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(getHash(user, amount, nonce, methodID, validAt, validUntil));
        bool valid = nonce == userNonce[user] &&
            validAt >= block.timestamp &&
            validUntil <= block.timestamp && 
            (methodID == WITHDRAW_SELECTOR || methodID == CLAIM_SELECTOR) && 
            user == ECDSA.recover(hash, signature);

        return (valid, methodID, user, amount);
    }

    function parseData(bytes calldata data) 
        public
        pure
        returns (
            address user,
            uint256 amount,
            uint256 nonce,
            bytes4 methodID,
            uint48 validAt,
            uint48 validUntil,
            bytes calldata signature
        )
    {
        (user, amount, nonce, methodID, validAt, validUntil) = abi.decode(
            data[VALID_DATA_OFFSET:SIGNATURE_OFFSET],
            (address, uint256, uint256, bytes4, uint48, uint48)
        );
        signature = data[SIGNATURE_OFFSET:];
    }
}
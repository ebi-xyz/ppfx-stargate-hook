// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import {IPPFX} from "./IPPFX.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IPPFXStargateHook} from "./IPPFXStargateHook.sol";

contract PPFXStargateHook is IPPFXStargateHook, Context, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 private constant VALID_DATA_OFFSET = 20;
    uint256 private constant SIGNATURE_OFFSET = 180;

    address public verifier;
    IPPFX public ppfx;

    constructor(IPPFX _ppfx) {
        ppfx = _ppfx;
    }

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

    function validate(bytes calldata data) external view returns (bool){
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
            "FundsManager: invalid signature length in data"
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
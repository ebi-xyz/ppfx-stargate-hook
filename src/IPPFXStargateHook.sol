// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

interface IPPFXStargateHook{
    function getHash(
        bytes4 selector, // deposit / withdraw / claim withdraw
        address user,
        uint256 amount,
        uint48 validAfter,
        uint48 validUntil
    ) external view returns (bytes32);

    function validate(bytes calldata data) external view returns (bool);

    function parseData(bytes calldata data) external pure returns (
            bytes4 selector,
            address user,
            uint256 amount,
            uint48 validAfter,
            uint48 validUntil,
            bytes calldata signature
        );
}
// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

/**
 * @dev Interface of the PPFX contract
 */
interface IPPFX {
    function depositForUser(address user, uint256 amount) external;
    function withdrawForUser(address user, uint256 amount) external;
    function claimPendingWithdrawalForUser(address user) external;
    function usdt() external returns (address);
}
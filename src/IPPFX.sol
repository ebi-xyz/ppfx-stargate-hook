// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

/**
 * @dev Interface of the PPFX contract
 */
interface IPPFX {
    function usdt() external returns (address);

    /**
     * @dev Deposit for a user
     * @param user The target address to deposit to
     * @param amount The amount to deposit
     */
    function depositForUser(address user, uint256 amount) external;

    /**
     * @dev Initiate a withdrawal for user.
     * @param delegate The delegated address to initiate the withdrawal
     * @param user The target address to withdraw from
     * @param amount The amount of USDT to withdraw
     * @param signature Signature from the user
     */
    function withdrawForUser(address delegate, address user, uint256 amount, bytes calldata signature) external;

    /**
     * @dev Claim all pending withdrawal for target user
     * Throw if no available pending withdrawal / invalid signature
     * @param delegate The delegated address to claim pending withdrawal
     * @param user The target address to claim pending withdrawal from
     * @param signature Signature from the user
     */
    function claimPendingWithdrawalForUser(address delegate, address user, bytes calldata signature) external;

}
// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

/**
 * @dev Interface of the PPFX contract
 */
interface IPPFX {

    /**
     * @dev Delegate Data used in withdrawForUser / claimPendingWithdrawalForUser
     * @param from signer address
     * @param delegate address delegating to
     * @param amount amount withdrawing, use 0 when claiming
     * @param deadline block timestamp on when the signature shouldn't be active anymore
     * @param signature signed getWithdrawHash() / getClaimHash()
     */
    struct DelegateData {
        address from;
        address delegate;
        uint256 amount;
        uint48 deadline;
        bytes signature;
    }

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
     * @param delegateData Delegate Data from the user
    */
    function withdrawForUser(address delegate, address user, uint256 amount, DelegateData calldata delegateData) external;

    /**
     * @dev Claim all pending withdrawal for target user
     * Throw if no available pending withdrawal / invalid delegate data / signature
     * @param delegate The delegated address to claim pending withdrawal
     * @param user The target address to claim pending withdrawal from
     * @param delegateData Delegate Data from the user
    */
    function claimPendingWithdrawalForUser(address delegate, address user, DelegateData calldata delegateData) external;

}
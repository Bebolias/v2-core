// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Account Manager Interface.
 * @notice Manages the system's account token NFT. Every user will need to register an account before being able to interact with
 * the protocol..
 */
interface IAccountManager {
    /**
     * @notice Thrown when the account interacting with the system is expected to be the associated account token, but is not.
     */
    error OnlyAccountTokenProxy(address origin);

    /**
     * @notice Emitted when an account token with id `accountId` is minted to `owner`.
     * @param accountId The id of the account.
     * @param owner The address that owns the created account.
     */
    event AccountCreated(uint128 indexed accountId, address indexed owner);

    /**
     * @notice Mints an account token with id `requestedAccountId` to `msg.sender`.
     * @param requestedAccountId The id requested for the account being created. Reverts if id already exists.
     *
     * Requirements:
     *
     * - `requestedAccountId` must not already be minted.
     *
     * Emits a {AccountCreated} event.
     */
    function createAccount(uint128 requestedAccountId) external;

    /**
     * @notice Called by AccountToken to notify the system when the account token is transferred.
     * @dev Resets user permissions and assigns ownership of the account token to the new holder.
     * @param to The new holder of the account NFT.
     * @param accountId The id of the account that was just transferred.
     *
     * Requirements:
     *
     * - `msg.sender` must be the account token.
     */
    function notifyAccountTransfer(address to, uint128 accountId) external;

    /**
     * @notice Returns the address for the account token used by the manager.
     * @return accountNftToken The address of the account token.
     */
    function getAccountTokenAddress() external view returns (address accountNftToken);

    /**
     * @notice Returns the address that owns a given account, as recorded by the protocol.
     * @param accountId The account id whose owner is being retrieved.
     * @return owner The owner of the given account id.
     */
    function getAccountOwner(uint128 accountId) external view returns (address owner);

    /**
     * @notice Checks wether a given `user` addres owns a given account identified by its `accountId`
     * @param accountId The account id whose ownership authority is being queried
     * @param user The address checked to have authority over a given account
     * @return _isAuthorized boolean value which is true only if the queried user owns a the account id
     */
    function isAuthorized(uint128 accountId, address user) external view returns (bool _isAuthorized);
}

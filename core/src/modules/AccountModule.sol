// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IAccountTokenModule.sol";
import "../interfaces/IAccountModule.sol";
import "../utils/modules/storage/AssociatedSystem.sol";
import "../storage/Account.sol";
import "../storage/AccountRBAC.sol";

/**
 * @title Account Manager.
 * @dev See IAccountModule.
 */
contract AccountModule is IAccountModule {
    using AccountRBAC for AccountRBAC.Data;
    using Account for Account.Data;

    bytes32 private constant _ACCOUNT_SYSTEM = "accountNFT";

    /**
     * @inheritdoc IAccountModule
     */
    function getAccountTokenAddress() public view override returns (address) {
        return AssociatedSystem.load(_ACCOUNT_SYSTEM).proxy;
    }

    /**
     * @inheritdoc IAccountModule
     */
    function createAccount(uint128 requestedAccountId) external override {
        IAccountTokenModule accountTokenModule = IAccountTokenModule(getAccountTokenAddress());
        accountTokenModule.safeMint(msg.sender, requestedAccountId, "");
        Account.create(requestedAccountId, msg.sender);
        emit AccountCreated(requestedAccountId, msg.sender);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyAccountToken();

        Account.Data storage account = Account.load(accountId);
        account.rbac.setOwner(to);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function getAccountOwner(uint128 accountId) public view returns (address) {
        return Account.load(accountId).rbac.owner;
    }

    /**
     * @inheritdoc IAccountModule
     */
    function isAuthorized(uint128 accountId, address user) public view override returns (bool _isAuthorized) {
        return Account.load(accountId).rbac.authorized(user);
    }

    /**
     * @dev Reverts if the caller is not the account token managed by this module.
     */
    function _onlyAccountToken() internal view {
        if (msg.sender != address(getAccountTokenAddress())) {
            revert OnlyAccountTokenProxy(msg.sender);
        }
    }
}

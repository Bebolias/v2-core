// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IAccountToken.sol";
import "../interfaces/IAccountManager.sol";
import "../utils/storage/AssociatedSystem.sol";
import "./storage/Account.sol";

/**
 * @title Account Manager.
 * @dev See IAccountManager.
 */
contract AccountManager is IAccountManager {
    bytes32 private constant _ACCOUNT_SYSTEM = "accountNFT";

    /**
     * @inheritdoc IAccountManager
     */
    function getAccountTokenAddress() public view override returns (address) {
        return AssociatedSystem.load(_ACCOUNT_SYSTEM).proxy;
    }

    /**
     * @inheritdoc IAccountManager
     */
    function createAccount(uint128 requestedAccountId) external override {
        IAccountToken accountToken = IAccountToken(getAccountTokenAddress());
        accountToken.safeMint(msg.sender, requestedAccountId, "");
        Account.create(requestedAccountId, msg.sender);
        emit AccountCreated(requestedAccountId, msg.sender);
    }

    /**
     * @inheritdoc IAccountManager
     */
    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyAccountToken();

        Account.Data storage account = Account.load(accountId);
        account.rbac.setOwner(to);
    }

    /**
     * @inheritdoc IAccountManager
     */
    function getAccountOwner(uint128 accountId) public view returns (address) {
        return Account.load(accountId).rbac.owner;
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

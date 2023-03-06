//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../../src/core/storage/Account.sol";

/**
 * @title Object for mocking account storage
 */
contract MockAccountStorage {
    using SetUtil for SetUtil.UintSet;
    using Account for Account.Data;

    struct CollateralBalance {
        address token;
        uint256 balance;
    }

    function mockAccount(
        uint128 accountId,
        address owner,
        CollateralBalance[] memory balances,
        uint128[] memory activeProductIds,
        address settlementToken
    )
        public
    {
        // Mock account
        Account.Data storage account = Account.create(accountId, owner);
        account.settlementToken = settlementToken;

        for (uint256 i = 0; i < balances.length; i++) {
            changeAccountBalance(accountId, balances[i]);
        }

        for (uint256 i = 0; i < activeProductIds.length; i++) {
            addActiveProduct(accountId, activeProductIds[i]);
        }
    }

    function changeAccountBalance(uint128 accountId, CollateralBalance memory balance) public {
        Account.Data storage account = Account.exists(accountId);

        address token = balance.token;
        uint256 balance = balance.balance;

        account.collaterals[token].balance = balance;
    }

    function addActiveProduct(uint128 accountId, uint128 productId) public {
        Account.Data storage account = Account.exists(accountId);
        account.activeProducts.add(productId);
    }

    function removeActiveProduct(uint128 accountId, uint128 productId) public {
        Account.Data storage account = Account.exists(accountId);
        account.activeProducts.remove(productId);
    }

    function getCollateralBalance(uint128 accountId, address collateralType) external view returns (uint256) {
        Account.Data storage account = Account.load(accountId);
        return account.getCollateralBalance(collateralType);
    }
}

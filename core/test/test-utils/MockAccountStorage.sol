//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../src/storage/Account.sol";

/**
 * @title Object for mocking account storage
 */
contract MockAccountStorage {
    using SetUtil for SetUtil.UintSet;
    using Account for Account.Data;

    struct CollateralBalance {
        address token;
        uint256 balance;
        uint256 liquidationBoosterBalance;
    }

    function mockAccount(
        uint128 accountId,
        address owner,
        CollateralBalance[] memory balances,
        uint128[] memory activeProductIds
    )
        public
    {
        // Mock account
        Account.create(accountId, owner);

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
        uint256 tokenBalance = balance.balance;
        uint256 liquidationBoosterBalance = balance.liquidationBoosterBalance;

        account.collaterals[token].balance = tokenBalance;
        account.collaterals[token].liquidationBoosterBalance = liquidationBoosterBalance;
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

    function getLiquidationBoosterBalance(uint128 accountId, address collateralType) external view returns (uint256) {
        Account.Data storage account = Account.load(accountId);
        return account.getLiquidationBoosterBalance(collateralType);
    }

    function getActiveProductsLength(uint128 accountId) public view returns (uint256) {
        Account.Data storage account = Account.exists(accountId);
        return account.activeProducts.length();
    }

    function getActiveProduct(uint128 accountId, uint256 index) public view returns (uint256 productId) {
        Account.Data storage account = Account.exists(accountId);
        return account.activeProducts.valueAt(index);
    }
}

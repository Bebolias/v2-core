//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../../src/core/storage/Account.sol";

/**
 * @title Object for mocking account storage
 */
contract MockAccount {
    using SetUtil for SetUtil.UintSet;

    struct CollateralBalance {
        address token;
        uint256 balanceD18;
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
        uint256 balanceD18 = balance.balanceD18;

        account.collaterals[token].balanceD18 = balanceD18;
    }

    function addActiveProduct(uint128 accountId, uint128 productId) public {
        Account.Data storage account = Account.exists(accountId);
        account.activeProducts.add(productId);
    }

    function removeActiveProduct(uint128 accountId, uint128 productId) public {
        Account.Data storage account = Account.exists(accountId);
        account.activeProducts.remove(productId);
    }
}

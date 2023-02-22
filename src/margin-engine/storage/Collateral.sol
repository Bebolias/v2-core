// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Stores information about a deposited asset for a given account.
 *
 * Each account will have one of these objects for each type of collateral it deposited in the system.
 */
library Collateral {
    struct Data {
        /**
         * @dev The net amount that is deposited in this collateral
         */
        uint256 balanceD18;
    }

    /**
     * @dev Increments the entry's balance.
     */
    function increaseAvailableCollateral(Data storage self, uint256 amountD18) internal {
        self.balance += amountD18;
    }

    /**
     * @dev Decrements the entry's balance.
     */
    function decreaseAvailableCollateral(Data storage self, uint256 amountD18) internal {
        self.balance -= amountD18;
    }
}

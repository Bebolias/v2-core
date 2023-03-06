// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Stores information about a deposited asset for a given account.
 *
 * Each account will have one of these objects for each type of collateral it deposited in the system.
 */
library Collateral {
    /**
     * @dev Thrown when an account does not have sufficient collateral.
     */
    error InsufficientCollateral(uint256 requestedAmount);

    struct Data {
        /**
         * @dev The net amount that is deposited in this collateral
         */
        uint256 balance;
    }

    /**
     * @dev Increments the entry's balance.
     */
    function increaseCollateralBalance(Data storage self, uint256 amount) internal {
        self.balance += amount;
    }

    /**
     * @dev Decrements the entry's balance.
     */
    function decreaseCollateralBalance(Data storage self, uint256 amount) internal {
        if (self.balance < amount) {
            revert InsufficientCollateral(amount);
        }

        self.balance -= amount;
    }
}

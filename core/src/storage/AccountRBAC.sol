// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Object for tracking an accounts permissions (role based access control).
 */

library AccountRBAC {
    struct Data {
        /**
         * @dev The owner of the account
         */
        address owner;
    }

    /**
     * @dev Sets the owner of the account.
     */
    function setOwner(Data storage self, address owner) internal {
        self.owner = owner;
    }

    /**
     * @dev Returns wether the specified target address is the owner of the account.
     */
    function authorized(Data storage self, address target) internal view returns (bool) {
        return target == self.owner;
    }
}

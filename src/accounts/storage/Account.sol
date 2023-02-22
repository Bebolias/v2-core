// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./AccountRBAC.sol";
import "../../utils/helpers/SafeCast.sol";
import "../../margin-engine/storage/Collateral.sol";

/**
 * @title Object for tracking accounts with access control and collateral tracking.
 */
library Account {
    using AccountRBAC for AccountRBAC.Data;
    // todo: do we need the safe casts in here?
    using SafeCastU128 for uint128;
    using SafeCastU256 for uint256;
    using SafeCastI128 for int128;
    using SafeCastI256 for int256;

    /**
     * @dev Thrown when the given target address does not own the given account.
     */
    error PermissionDenied(uint128 accountId, address target);

    /**
     * @dev Thrown when an account cannot be found.
     */
    error AccountNotFound(uint128 accountId);

    /**
     * @dev Thrown when an account does not have sufficient collateral for a particular operation in the protocol.
     */
    error InsufficientAccountCollateral(uint256 requestedAmount);

    struct Data {
        /**
         * @dev Numeric identifier for the account. Must be unique.
         * @dev There cannot be an account with id zero (See ERC721._mint()).
         */
        uint128 id;
        /**
         * @dev Role based access control data for the account.
         */
        AccountRBAC.Data rbac;
        /**
         * @dev Address set of collaterals that are being used in the protocols by this account.
         */
        mapping(address => Collateral.Data) collaterals;
    }

    /**
     * @dev Returns the account stored at the specified account id.
     */
    function load(uint128 id) internal pure returns (Data storage account) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Account", id));
        assembly {
            account.slot := s
        }
    }

    /**
     * @dev Creates an account for the given id, and associates it to the given owner.
     *
     * Note: Will not fail if the account already exists, and if so, will overwrite the existing owner.
     *  Whatever calls this internal function must first check that the account doesn't exist before re-creating it.
     */
    function create(uint128 id, address owner) internal returns (Data storage account) {
        account = load(id);

        account.id = id;
        account.rbac.owner = owner;
    }

    /**
     * @dev Reverts if the account does not exist with appropriate error. Otherwise, returns the account.
     */
    function exists(uint128 id) internal view returns (Data storage account) {
        Data storage a = load(id);
        if (a.rbac.owner == address(0)) {
            revert AccountNotFound(id);
        }

        return a;
    }

    /**
     * @dev Given a collateral type, returns information about the total balance of the account
     */
    function getCollateralBalance(Data storage self, address collateralType)
        internal
        view
        returns (uint256 totalBalanceD18)
    {
        totalBalanceD18 = self.balanceD18;
        return totalBalanceD18;
    }

    /**
     * @dev Loads the Account object for the specified accountId,
     * and validates that sender has the ownership of the account id. These
     * are different actions but they are merged in a single function
     * because loading an account and checking for ownership is a very
     * common use case in other parts of the code.
     */
    function loadAccountAndValidateOwnership(uint128 accountId) internal returns (Data storage account) {
        account = Account.load(accountId);
        if (!account.rbac.authorized(msg.sender)) {
            revert PermissionDenied(accountId, msg.sender);
        }
    }
}

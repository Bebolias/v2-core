// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./AccountRBAC.sol";
import "../../utils/helpers/SafeCast.sol";
import "../../margin-engine/storage/Collateral.sol";
import "../../products/storage/Product.sol";

/**
 * @title Object for tracking accounts with access control and collateral tracking.
 */
library Account {
    using AccountRBAC for AccountRBAC.Data;
    using Product for Product.Data;

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
        /**
         * @dev Ids of all the products in which the account has active positions
         * todo: needs logic to mark active products (check out python)
         */
        uint128[] activeProductIds;
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
        returns (uint256 collateralBalanceD18)
    {
        collateralBalanceD18 = self.collaterals[collateralType].balanceD18;
        return collateralBalanceD18;
    }

    /**
     * @dev Loads the Account object for the specified accountId,
     * and validates that sender has the ownership of the account id. These
     * are different actions but they are merged in a single function
     * because loading an account and checking for ownership is a very
     * common use case in other parts of the code.
     */
    function loadAccountAndValidateOwnership(uint128 accountId) internal view returns (Data storage account) {
        account = Account.load(accountId);
        if (!account.rbac.authorized(msg.sender)) {
            revert PermissionDenied(accountId, msg.sender);
        }
    }

    struct Exposure {
        // productId (IRS) -> marketID (aUSDC lend) -> maturity (30th December)
        // productId (Dated Future) -> marketID (BTC) -> maturity (30th December)
        // productId (Perp) -> marketID (ETH)
        // note, we don't neeed to keep track of the maturity for the purposes of of IM, LM calc
        // because the risk parameter is shared across maturities for a given productId marketId pair
        uint128 productId;
        uint128 marketId;
        int256 filled;
        uint256 unfilledLong;
        uint256 unfilledShort;
    }

    /**
     * @dev Returns the aggregate annualized exposures of the account in all products in which the account is active
     */
    function getAccountAnnualizedExposures(Data storage self) internal view returns (Exposure[] memory exposures) {
        uint128[] memory _activeProductIds = self.activeProductIds;
        // consider following the below pattern instead
        // ref: https://github.com/Synthetixio/synthetix-v3/blob/91d59830636f8d367c41f5d42f043993ebc39992/protocol/synthetix/contracts/storage/Account.sol#L129
        for (uint256 i = 1; i < _activeProductIds.length; i++) {
            Product.Data storage _product = Product.load(_activeProductIds[i]);
            Exposure memory _exposure = _product.getAccountAnnualizedExposures(self.id);
            exposures.push(_exposure);
        }
    }
}

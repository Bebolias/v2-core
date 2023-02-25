// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./AccountRBAC.sol";
import "../../utils/helpers/SafeCast.sol";
import "../../utils/helpers/SetUtil.sol";
import "../../margin-engine/storage/Collateral.sol";
import "../../products/storage/Product.sol";

/**
 * @title Object for tracking accounts with access control and collateral tracking.
 */
library Account {
    using AccountRBAC for AccountRBAC.Data;
    using Product for Product.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU128 for uint128;
    using SafeCastU256 for uint256;

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
         * todo: needs logic to mark active products (check out python) and also check out how marking is done in synthetix, how and why they use sets vs. simple arrays
         */
        SetUtil.UintSet activeProducts;
        /**
         * @dev A single token account can only create positions that settle in the account's settlement token
         * @dev A single token account can only deposit collateral type that's the same as the account's settlement token
         * @dev If a user wants to engage in positions with a different settlement token, they can create a new account with a
         * different settlement token
         * @dev The settlement token of the account is defined as soon as the account makes its first deposit where the
         * settlement token is set to the collateral type of the first deposit
         * note, for the time being the settlement token cannot be changed for a given account as soon as it's initialised
         * following the first deposit
         */
        address settlementToken;
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
     * @dev Closes all account filled (i.e. attempts to fully unwind) and unfilled orders in all the products in which the account is active
     */
    function closeAccount(Data storage self) internal {
        SetUtil.UintSet storage _activeProducts = self.activeProducts;
        for (uint256 i = 1; i < _activeProducts.length(); i++) {
            uint128 productIndex = _activeProducts.valueAt(i).to128();
            Product.Data storage _product = Product.load(productIndex);
            _product.closeAccount(self.id);
        }
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

    /**
     * @dev Returns the aggregate annualized exposures of the account in all products in which the account is active
     * note, the annualized exposures are expected to be in notional terms and in terms of the settlement token of this account
     */
    function getAnnualizedExposures(Data storage self) internal view returns (Exposure[] memory exposures) {
        SetUtil.UintSet storage _activeProducts = self.activeProducts;
        // consider following the below pattern instead
        // ref: https://github.com/Synthetixio/synthetix-v3/blob/91d59830636f8d367c41f5d42f043993ebc39992/protocol/synthetix/contracts/storage/Account.sol#L129
        for (uint256 i = 1; i < _activeProducts.length(); i++) {
            uint128 productIndex = _activeProducts.valueAt(i).to128();
            Product.Data storage _product = Product.load(productIndex);
            Exposure memory _exposure = _product.getAccountAnnualizedExposures(self.id);
            exposures.push(_exposure);
        }
    }

    /**
     * @dev Returns the aggregate unrealized pnl of the account in all products in which the account has positions with unrealized pnl
     * note, the unrealized pnl is expected to be in terms of the settlement token of this account
     */
    function getUnrealizedPnL(Data storage self) internal view returns (int256 unrealizedPnL) {
        SetUtil.UintSet storage _activeProducts = self.activeProducts;
        for (uint256 i = 1; i < _activeProducts.length(); i++) {
            uint128 productIndex = _activeProducts.valueAt(i).to128();
            Product.Data storage _product = Product.load(productIndex);
            unrealizedPnL += _product.getAccountUnrealizedPnL(self.id);
        }
    }
}

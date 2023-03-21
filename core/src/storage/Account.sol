// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./MarketRiskConfiguration.sol";
import "./ProtocolRiskConfiguration.sol";
import "./AccountRBAC.sol";
import "../utils/contracts//helpers/SafeCast.sol";
import "../utils/contracts//helpers/SetUtil.sol";
import "./Collateral.sol";
import "./Product.sol";

/**
 * @title Object for tracking accounts with access control and collateral tracking.
 */
library Account {
    using MarketRiskConfiguration for MarketRiskConfiguration.Data;
    using ProtocolRiskConfiguration for ProtocolRiskConfiguration.Data;
    using Account for Account.Data;
    using AccountRBAC for AccountRBAC.Data;
    using Product for Product.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU128 for uint128;
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    /**
     * @dev Thrown when the given target address does not own the given account.
     */
    error PermissionDenied(uint128 accountId, address target);

    /**
     * @dev Thrown when a given account's total value is below the initial margin requirement
     */
    error AccountBelowIM(uint128 accountId);

    /**
     * @dev Thrown when an account cannot be found.
     */
    error AccountNotFound(uint128 accountId);

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
         * todo: needs logic to mark active products (check out python) and also check out how marking is done in synthetix, how and
         * why they use sets vs. simple arrays
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
        // uint128 productId; -> since already have it in the exposures mapping
        uint128 marketId;
        int256 filled;
        // this value should technically be uint256, however using int256 to minimise need for casting
        // todo: consider using uint256 for the below values since they should never be negative
        int256 unfilledLong;
        int256 unfilledShort;
    }

    /**
     * @dev Returns the account stored at the specified account id.
     */
    function load(uint128 id) internal pure returns (Data storage account) {
        require(id != 0);
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
        // Disallowing account ID 0 means we can use a non-zero accountId as an existence flag in structs like Position
        require(id != 0);
        account = load(id);

        account.id = id;
        account.rbac.owner = owner;
    }

    /**
     * @dev Closes all account filled (i.e. attempts to fully unwind) and unfilled orders in all the products in which the account
     * is active
     */
    function closeAccount(Data storage self) internal {
        SetUtil.UintSet storage _activeProducts = self.activeProducts;
        for (uint256 i = 1; i <= _activeProducts.length(); i++) {
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
    function getCollateralBalance(Data storage self, address collateralType) internal view returns (uint256 collateralBalanceD18) {
        collateralBalanceD18 = self.collaterals[collateralType].balance;
        return collateralBalanceD18;
    }

    /**
     * @dev Given a collateral type, returns information about the total balance of the account that's available to withdraw
     */
    function getCollateralBalanceAvailable(
        Data storage self,
        address collateralType
    )
        internal
        returns (uint256 collateralBalanceAvailableD18)
    {
        if (collateralType == self.settlementToken) {
            (uint256 im,) = self.getMarginRequirements();
            int256 totalAccountValue = self.getTotalAccountValue();
            if (totalAccountValue > im.toInt()) {
                collateralBalanceAvailableD18 = totalAccountValue.toUint() - im;
            }
        } else {
            collateralBalanceAvailableD18 = self.getCollateralBalance(collateralType);
        }
    }

    /**
     * @dev Loads the Account object for the specified accountId,
     * and validates that sender has the ownership of the account id. These
     * are different actions but they are merged in a single function
     * because loading an account and checking for ownership is a very
     * common use case in other parts of the code.
     */
    function loadAccountAndValidateOwnership(
        uint128 accountId,
        address senderAddress
    )
        internal
        view
        returns (Data storage account)
    {
        account = Account.load(accountId);
        if (!account.rbac.authorized(senderAddress)) {
            revert PermissionDenied(accountId, senderAddress);
        }
    }

    /**
     * @dev Returns the aggregate annualized exposures of the account in all products in which the account is active (annualized
     * exposures are per product)
     * note, the annualized exposures are expected to be in notional terms and in terms of the settlement token of this account
     * what if we do margin calculations per product for now, that'd help with bringing down the gas costs (since atm we're doing no
     * correlations)
     */
    function getAnnualizedProductExposures(
        Data storage self,
        uint128 productId
    )
        internal
        returns (Exposure[] memory productExposures)
    {
        Product.Data storage _product = Product.load(productId);
        productExposures = _product.getAccountAnnualizedExposures(self.id);
    }

    /**
     * @dev Returns the aggregate unrealized pnl of the account in all products in which the account has positions with unrealized
     * pnl
     * note, the unrealized pnl is expected to be in terms of the settlement token of this account
     */
    function getUnrealizedPnL(Data storage self) internal view returns (int256 unrealizedPnL) {
        SetUtil.UintSet storage _activeProducts = self.activeProducts;
        for (uint256 i = 1; i <= _activeProducts.length(); i++) {
            uint128 productIndex = _activeProducts.valueAt(i).to128();
            Product.Data storage _product = Product.load(productIndex);
            unrealizedPnL += _product.getAccountUnrealizedPnL(self.id);
        }
    }

    /**
     * @dev Returns the total account value in terms of the quote token of the (single token) account
     */

    function getTotalAccountValue(Data storage self) internal view returns (int256 totalAccountValue) {
        int256 unrealizedPnL = self.getUnrealizedPnL();
        int256 collateralBalance = self.getCollateralBalance(self.settlementToken).toInt();
        totalAccountValue = unrealizedPnL + collateralBalance;
    }

    function getRiskParameter(uint128 productId, uint128 marketId) internal view returns (int256 riskParameter) {
        return MarketRiskConfiguration.load(productId, marketId).riskParameter;
    }

    /**
     * @dev Note, im multiplier is assumed to be the same across all products, markets and maturities
     */
    function getIMMultiplier() internal view returns (uint256 imMultiplier) {
        return ProtocolRiskConfiguration.load().imMultiplier;
    }

    function imCheck(Data storage self) internal {
        (bool isSatisfied,) = self.isIMSatisfied();
        if (!isSatisfied) {
            revert AccountBelowIM(self.id);
        }
    }

    /**
     * @dev Comes out as true if a given account initial margin requirement is satisfied
     * i.e. account value (collateral + unrealized pnl) >= initial margin requirement
     */
    function isIMSatisfied(Data storage self) internal returns (bool imSatisfied, uint256 im) {
        (im,) = self.getMarginRequirements();
        imSatisfied = self.getTotalAccountValue() >= im.toInt();
    }

    /**
     * @dev Comes out as true if a given account is liquidatable, i.e. account value (collateral + unrealized pnl) < lm
     */

    function isLiquidatable(Data storage self) internal returns (bool liquidatable, uint256 im, uint256 lm) {
        (im, lm) = self.getMarginRequirements();
        liquidatable = self.getTotalAccountValue() < lm.toInt();
    }
    /**
     * @dev Returns the initial (im) and liqudiation (lm) margin requirements of the account
     * todo: add user defined types
     * todo: consider representing im and lm as uint256 with casting in the function body
     * when summations with int256 need to take place
     */

    function getMarginRequirements(Data storage self) internal returns (uint256 im, uint256 lm) {
        SetUtil.UintSet storage _activeProducts = self.activeProducts;

        int256 worstCashflowUp;
        int256 worstCashflowDown;
        for (uint256 i = 1; i <= _activeProducts.length(); i++) {
            uint128 productId = _activeProducts.valueAt(i).to128();
            Exposure[] memory annualizedProductMarketExposures = self.getAnnualizedProductExposures(productId);

            for (uint256 j = 0; j < annualizedProductMarketExposures.length; j++) {
                Exposure memory exposure = annualizedProductMarketExposures[j];
                uint128 marketId = exposure.marketId;
                int256 riskParameter = getRiskParameter(productId, marketId);
                int256 maxLong = exposure.filled + exposure.unfilledLong;
                int256 maxShort = exposure.filled + exposure.unfilledShort;
                // note: this conditional logic is redundunt if no correlations, should just be maxLong
                // hence, why we need to use int256 for risk parameter + minimises need for casting
                int256 worstFilledUp = riskParameter > 0 ? maxLong : maxShort;
                int256 worstFilledDown = riskParameter > 0 ? maxShort : maxLong;

                worstCashflowUp += worstFilledUp * riskParameter / 1e18;
                worstCashflowDown += worstFilledDown * riskParameter / 1e18;
            }
        }
        (worstCashflowUp, worstCashflowDown) = (abs(worstCashflowUp), abs(worstCashflowDown));
        lm = max(worstCashflowUp, worstCashflowDown).toUint();

        im = lm * getIMMultiplier() / 1e18;
    }

    // todo: consider replacing with prb math
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }
    /**
     * @dev Returns the initial (im) and liqudiation (lm) margin requirements of the account
     *  todo: consider replacing with prb math
     */

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}

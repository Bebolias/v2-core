//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../interfaces/external/IProduct.sol";
import "../interfaces/IProductModule.sol";
import "../interfaces/ICollateralModule.sol";
import "../storage/Product.sol";
import "../storage/ProductCreator.sol";
import "../storage/MarketFeeConfiguration.sol";
import "@voltz-protocol/util-modules/src/storage/AssociatedSystem.sol";
import "@voltz-protocol/util-contracts/src/helpers/ERC165Helper.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";
import "oz/utils/math/SignedMath.sol";

import {mulUDxUint} from "@voltz-protocol/util-contracts/src/helpers/PrbMathHelper.sol";

/**
 * @title Protocol-wide entry point for the management of products connected to the protocol.
 * @dev See IProductModule
 */
contract ProductModule is IProductModule {
    using Account for Account.Data;
    using Product for Product.Data;
    using MarketFeeConfiguration for MarketFeeConfiguration.Data;
    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;
    using AssociatedSystem for AssociatedSystem.Data;
    using Collateral for Collateral.Data;
    using SetUtil for SetUtil.UintSet;

    bytes32 private constant _REGISTER_PRODUCT_FEATURE_FLAG = "registerProduct";

    /**
     * @inheritdoc IProductModule
     */
    function getAccountUnrealizedPnL(uint128 productId, uint128 accountId, address collateralType)
        external
        view
        override
        returns (int256 accountUnrealizedPnL)
    {
        accountUnrealizedPnL = Product.load(productId).getAccountUnrealizedPnL(accountId, collateralType);
    }

    /**
     * @inheritdoc IProductModule
     */
    function getAccountAnnualizedExposures(uint128 productId, uint128 accountId, address collateralType)
        external
        override
        returns (Account.Exposure[] memory exposures)
    {
        exposures = Product.load(productId).getAccountAnnualizedExposures(accountId, collateralType);
    }

    /**
     * @inheritdoc IProductModule
     */
    function registerProduct(address product, string memory name) external override returns (uint128 productId) {
        FeatureFlag.ensureAccessToFeature(_REGISTER_PRODUCT_FEATURE_FLAG);

        if (!ERC165Helper.safeSupportsInterface(product, type(IProduct).interfaceId)) {
            revert IncorrectProductInterface(product);
        }

        productId = ProductCreator.create(product, name, msg.sender).id;

        emit ProductRegistered(product, productId, name, msg.sender, block.timestamp);
    }

    /**
     * @inheritdoc IProductModule
     */

    function closeAccount(uint128 productId, uint128 accountId, address collateralType) external override {
        // todo: consider returning data that might be useful in the future

        Account.loadAccountAndValidatePermission(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender);
        Product.load(productId).closeAccount(accountId, collateralType);

        emit AccountClosed(accountId, productId, collateralType, block.timestamp);
    }

    /**
     * @dev Internal function to distribute trade fees according to the market fee config
     * @param payingAccountId Account id of trade initiatior
     * @param receivingAccountId Account id of fee collector
     * @param atomicFee Fee percentage of annualized notional to be distributed
     * @param collateralType Quote token used to pay fees in
     * @param annualizedNotional Traded annualized notional
     */
    function distributeFees(
        uint128 payingAccountId,
        uint128 receivingAccountId,
        UD60x18 atomicFee,
        address collateralType,
        int256 annualizedNotional
    ) internal returns (uint256 fee) {
        fee = mulUDxUint(atomicFee, SignedMath.abs(annualizedNotional));

        Account.Data storage payingAccount = Account.exists(payingAccountId);
        payingAccount.collaterals[collateralType].decreaseCollateralBalance(fee);
        emit Collateral.CollateralUpdate(payingAccountId, collateralType, -fee.toInt(), block.timestamp);

        Account.Data storage receivingAccount = Account.exists(receivingAccountId);
        receivingAccount.collaterals[collateralType].increaseCollateralBalance(fee);
        emit Collateral.CollateralUpdate(receivingAccountId, collateralType, fee.toInt(), block.timestamp);
    }

    function propagateTakerOrder(
        uint128 accountId,
        uint128 productId,
        uint128 marketId,
        address collateralType,
        int256 annualizedNotional
    ) external override returns (uint256 fee) {
        Product.onlyProductAddress(productId, msg.sender);

        MarketFeeConfiguration.Data memory feeConfig = MarketFeeConfiguration.load(productId, marketId);
        fee = distributeFees(
            accountId, feeConfig.feeCollectorAccountId, feeConfig.atomicTakerFee, collateralType, annualizedNotional
        );

        Account.Data storage account = Account.exists(accountId);
        account.imCheck(collateralType);
        if (!account.activeProducts.contains(productId)) {
            account.activeProducts.add(productId);
            emit NewActiveProduct(accountId, productId, block.timestamp);
        }

        emit TakerOrderPropagated(accountId, productId, marketId, collateralType, annualizedNotional, fee, block.timestamp);
    }

    function propagateMakerOrder(
        uint128 accountId,
        uint128 productId,
        uint128 marketId,
        address collateralType,
        int256 annualizedNotional
    ) external override returns (uint256 fee) {
        Product.onlyProductAddress(productId, msg.sender);

        MarketFeeConfiguration.Data memory feeConfig = MarketFeeConfiguration.load(productId, marketId);
        fee = distributeFees(
            accountId, feeConfig.feeCollectorAccountId, feeConfig.atomicMakerFee, collateralType, annualizedNotional
        );

        Account.Data storage account = Account.exists(accountId);
        account.imCheck(collateralType);
        if (!account.activeProducts.contains(productId)) {
            account.activeProducts.add(productId);
            emit NewActiveProduct(accountId, productId, block.timestamp);
        }

        emit MakerOrderPropagated(accountId, productId, marketId, collateralType, annualizedNotional, fee, block.timestamp);
    }

    function propagateCashflow(uint128 accountId, uint128 productId, address collateralType, int256 amount)
        external
        override
    {
        Product.onlyProductAddress(productId, msg.sender);

        Account.Data storage account = Account.exists(accountId);
        if (amount > 0) {
            account.collaterals[collateralType].increaseCollateralBalance(amount.toUint());
            emit Collateral.CollateralUpdate(accountId, collateralType, amount, block.timestamp);
        } else {
            account.collaterals[collateralType].decreaseCollateralBalance((-amount).toUint());
            emit Collateral.CollateralUpdate(accountId, collateralType, amount, block.timestamp);
        }


        //todo: imcheck?

        emit CashflowPropagated(accountId, productId, collateralType, amount, block.timestamp);
    }
}

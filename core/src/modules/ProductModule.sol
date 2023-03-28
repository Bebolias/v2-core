//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/external/IProduct.sol";
import "../interfaces/IProductModule.sol";
import "../interfaces/ICollateralModule.sol";
import "../storage/Product.sol";
import "../storage/ProductCreator.sol";
import "../storage/MarketFeeConfiguration.sol";
import "@voltz-protocol/util-modules/src/storage/AssociatedSystem.sol";
import "@voltz-protocol/util-contracts/src/helpers/ERC165Helper.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";

import { UD60x18, unwrap, mul } from "@prb/math/UD60x18.sol";

/**
 * @title Protocol-wide entry point for the management of products connected to the protocol.
 * @dev See IProductModule
 */
contract ProductModule is IProductModule {
    using Account for Account.Data;
    using Product for Product.Data;
    using MarketFeeConfiguration for MarketFeeConfiguration.Data;
    using SafeCastI256 for int256;
    using AssociatedSystem for AssociatedSystem.Data;
    using Collateral for Collateral.Data;
    
    using { unwrap } for UD60x18;

    /**
     * @inheritdoc IProductModule
     */
    function getAccountUnrealizedPnL(
        uint128 productId,
        uint128 accountId
    )
        external
        view
        override
        returns (int256 accountUnrealizedPnL)
    {
        accountUnrealizedPnL = Product.load(productId).getAccountUnrealizedPnL(accountId);
    }

    /**
     * @inheritdoc IProductModule
     */
    function getAccountAnnualizedExposures(
        uint128 productId,
        uint128 accountId
    )
        external
        override
        returns (Account.Exposure[] memory exposures)
    {
        exposures = Product.load(productId).getAccountAnnualizedExposures(accountId);
    }

    /**
     * @inheritdoc IProductModule
     */
    function registerProduct(address product, string memory name) external override returns (uint128 productId) {
        // todo: ensure acces to feature flag check

        if (!ERC165Helper.safeSupportsInterface(product, type(IProduct).interfaceId)) {
            revert IncorrectProductInterface(product);
        }

        productId = ProductCreator.create(product, name, msg.sender).id;

        emit ProductRegistered(product, productId, msg.sender);

        return productId;
    }

    /**
     * @inheritdoc IProductModule
     */

    function closeAccount(uint128 productId, uint128 accountId) external override {
        // todo: consider returning data that might be useful in the future
        // why should this function be exposed in here?
        Product.load(productId).closeAccount(accountId);
    }

    /**
     * @dev Internal function to distribute trade fees according to the market fee config
     * @param payingAccountId Account id of trade initiatior
     * @param receivingAccountId Account id of fee collector
     * @param settlementToken Quote token used to pay fees in
     * @param annualizedNotional Traded annualized notional
     */
    function distributeFees(
        uint128 payingAccountId, uint128 receivingAccountId, UD60x18 atomicFee, 
        address settlementToken, uint256 annualizedNotional
    ) internal returns (uint256 fee) {
        fee = mul(UD60x18.wrap(annualizedNotional), atomicFee).unwrap();

        Account.Data storage payingAccount = Account.load(payingAccountId);
        payingAccount.collaterals[settlementToken].decreaseCollateralBalance(fee);

        Account.Data storage receivingAccount = Account.load(receivingAccountId);
        receivingAccount.collaterals[settlementToken].increaseCollateralBalance(fee);
    }

    // check if account exists
    // or consider calling the product maneger once to do all the checks and updates
    // todo: mark product in the account object (see python implementation for more details, solidity uses setutil though)
    function propagateTakerOrder(
        uint128 accountId, uint128 productId, uint128 marketId, address settlementToken, uint256 annualizedNotional
    ) 
        external override returns (uint256 fee)
    {
        Product.onlyProductAddress(productId, msg.sender);

        MarketFeeConfiguration.Data memory feeConfig = MarketFeeConfiguration.load(productId, marketId);
        fee = distributeFees(
            accountId, feeConfig.feeCollectorAccountId, feeConfig.atomicTakerFee, settlementToken, annualizedNotional
        );

        Account.Data storage account = Account.load(accountId);
        account.imCheck();
    }

    // todo: mark product
    function propagateMakerOrder(
        uint128 accountId, uint128 productId, uint128 marketId, address settlementToken, uint256 annualizedNotional
    ) 
        external override returns (uint256 fee)
    {
        Product.onlyProductAddress(productId, msg.sender);
        
        MarketFeeConfiguration.Data memory feeConfig = MarketFeeConfiguration.load(productId, marketId);
        fee = distributeFees(
            accountId, feeConfig.feeCollectorAccountId, feeConfig.atomicMakerFee, settlementToken, annualizedNotional
        );
        
        Account.Data storage account = Account.load(accountId);
        account.imCheck();
    }

    function propagateCashflow(uint128 accountId, address settlementToken, int256 amount) external override {
        Account.Data storage account = Account.load(accountId);
        if (amount > 0) {
            account.collaterals[settlementToken].increaseCollateralBalance(amount.toUint());
        } else {
            account.collaterals[settlementToken].decreaseCollateralBalance((-amount).toUint());
        }
    }
}

/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "../interfaces/IProductIRSModule.sol";
import "@voltz-protocol/core/src/interfaces/IAccountModule.sol";
import "@voltz-protocol/core/src/storage/Account.sol";
import "@voltz-protocol/core/src/storage/AccountRBAC.sol";
import "../storage/Portfolio.sol";
import "../storage/MarketConfiguration.sol";
import "../storage/ProductConfiguration.sol";
import "../storage/RateOracleReader.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/core/src/interfaces/IProductModule.sol";
import "@voltz-protocol/core/src/interfaces/IRiskConfigurationModule.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

/**
 * @title Dated Interest Rate Swap Product
 * @dev See IProductIRSModule
 */

contract ProductIRSModule is IProductIRSModule {
    using RateOracleReader for RateOracleReader.Data;
    using Portfolio for Portfolio.Data;
    using SafeCastI256 for int256;

    /**
     * @inheritdoc IProductIRSModule
     */
    function initiateTakerOrder(
        uint128 accountId,
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 baseAmount,
        uint160 priceLimit
    )
        external
        override
        returns (int256 executedBaseAmount, int256 executedQuoteAmount, uint256 fee, uint256 im, uint256 highestUnrealizedLoss)
    {
        address coreProxy = ProductConfiguration.getCoreProxyAddress();

        // check account access permissions
        IAccountModule(coreProxy).onlyAuthorized(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender);

        // check if market id is valid + check there is an active pool with maturityTimestamp requested
        (executedBaseAmount, executedQuoteAmount) =
            IPool(ProductConfiguration.getPoolAddress()).executeDatedTakerOrder(marketId, maturityTimestamp, baseAmount, priceLimit);
        Portfolio.loadOrCreate(accountId).updatePosition(marketId, maturityTimestamp, executedBaseAmount, executedQuoteAmount);

        // propagate order
        address quoteToken = MarketConfiguration.load(marketId).quoteToken;
        int256 annualizedNotionalAmount = getSingleAnnualizedExposure(executedBaseAmount, marketId, maturityTimestamp);
        
        uint128 productId = ProductConfiguration.getProductId();
        (fee, im, highestUnrealizedLoss) = IProductModule(coreProxy).propagateTakerOrder(
            accountId,
            productId,
            marketId,
            quoteToken,
            annualizedNotionalAmount
        );

        emit TakerOrder(
            accountId,
            productId,
            marketId,
            maturityTimestamp,
            quoteToken,
            executedBaseAmount,
            executedQuoteAmount,
            annualizedNotionalAmount,
            block.timestamp
            );

    }

    function getSingleAnnualizedExposure(
        int256 executedBaseAmount,
        uint128 marketId,
        uint32 maturityTimestamp
    ) internal returns (int256 annualizedNotionalAmount) {
        int256[] memory baseAmounts = new int256[](1);
        baseAmounts[0] = executedBaseAmount;
        annualizedNotionalAmount = baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp)[0];
    }

    /**
     * @inheritdoc IProductIRSModule
     */
    // note: return settlementCashflowInQuote?
    function settle(uint128 accountId, uint128 marketId, uint32 maturityTimestamp) external override {

        RateOracleReader.load(marketId).updateRateIndexAtMaturityCache(maturityTimestamp);

        address coreProxy = ProductConfiguration.getCoreProxyAddress();

        // check account access permissions
        IAccountModule(coreProxy).onlyAuthorized(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender);

        Portfolio.Data storage portfolio = Portfolio.exists(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        int256 settlementCashflowInQuote = portfolio.settle(marketId, maturityTimestamp, poolAddress);

        address quoteToken = MarketConfiguration.load(marketId).quoteToken;

        uint128 productId = ProductConfiguration.getProductId();

        IProductModule(coreProxy).propagateSettlementCashflow(accountId, productId, quoteToken, settlementCashflowInQuote);

        emit DatedIRSPositionSettled(
            accountId, productId, marketId, maturityTimestamp, quoteToken, settlementCashflowInQuote, block.timestamp
            );
    }

    /**
     * @inheritdoc IProduct
     */
    function name() external pure override returns (string memory) {
        return "Dated IRS Product";
    }


    /**
     * @inheritdoc IProduct
     */
    function baseToAnnualizedExposure(
        int256[] memory baseAmounts,
        uint128 marketId,
        uint32 maturityTimestamp
    )
        public
        view
        returns (int256[] memory exposures)
    {
        exposures = new int256[](baseAmounts.length);
        exposures = Portfolio.baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp);
    }

    /**
     * @inheritdoc IProduct
     */
    function getAccountTakerAndMakerExposures(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (Account.Exposure[] memory takerExposures, Account.Exposure[] memory makerExposuresLower, Account.Exposure[] memory makerExposuresUpper)
    {
        Portfolio.Data storage portfolio = Portfolio.exists(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        return portfolio.getAccountTakerAndMakerExposures(poolAddress, collateralType);
    }

    /**
     * @inheritdoc IProduct
     */
    function closeAccount(uint128 accountId, address collateralType) external override {
        address coreProxy = ProductConfiguration.getCoreProxyAddress();

        if (
            !IAccountModule(coreProxy).isAuthorized(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender)
                && msg.sender != ProductConfiguration.getCoreProxyAddress()
        ) {
            revert NotAuthorized(msg.sender, "closeAccount");
        }

        Portfolio.Data storage portfolio = Portfolio.exists(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        portfolio.closeAccount(poolAddress, collateralType);
    }

    function configureProduct(ProductConfiguration.Data memory config) external {
        OwnableStorage.onlyOwner();

        ProductConfiguration.set(config);
        emit ProductConfigured(config, block.timestamp);
    }

    /**
     * @inheritdoc IProductIRSModule
     */
    function getCoreProxyAddress() external returns (address) {
        return ProductConfiguration.getCoreProxyAddress();
    }

    /**
     * @inheritdoc IProductIRSModule
     */
    function propagateMakerOrder(
        uint128 accountId,
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 baseAmount
    ) external returns (uint256 fee, uint256 im, uint256 highestUnrealizedLoss) {

        if (msg.sender != ProductConfiguration.getPoolAddress()) {
            revert NotAuthorized(msg.sender, "propagateMakerOrder");
        }

        Portfolio.loadOrCreate(accountId).updatePosition(marketId, maturityTimestamp, 0, 0);

        int256 annualizedNotionalAmount = getSingleAnnualizedExposure(baseAmount, marketId, maturityTimestamp);

        address coreProxy = ProductConfiguration.getCoreProxyAddress();
        (fee, im, highestUnrealizedLoss) = IProductModule(coreProxy).propagateMakerOrder(
            accountId,
            ProductConfiguration.getProductId(),
            marketId,
            MarketConfiguration.load(marketId).quoteToken,
            annualizedNotionalAmount
        );

    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

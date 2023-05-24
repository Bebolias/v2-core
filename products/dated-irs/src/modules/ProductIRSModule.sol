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
        int256 baseAmount
    )
        external
        override
        returns (int256 executedBaseAmount, int256 executedQuoteAmount)
    {
        address coreProxy = ProductConfiguration.getCoreProxyAddress();

        // check account access permissions
        IAccountModule(coreProxy).onlyAuthorized(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender);

        // update rate oracle cache if empty or hasn't been updated in a while
        RateOracleReader.load(marketId).updateCache(maturityTimestamp);

        // check if market id is valid + check there is an active pool with maturityTimestamp requested
        address poolAddress = ProductConfiguration.getPoolAddress();
        Portfolio.Data storage portfolio = Portfolio.load(accountId);
        IPool pool = IPool(poolAddress);
        (executedBaseAmount, executedQuoteAmount) = pool.executeDatedTakerOrder(marketId, maturityTimestamp, baseAmount);
        portfolio.updatePosition(marketId, maturityTimestamp, executedBaseAmount, executedQuoteAmount);

        // propagate order
        address quoteToken = MarketConfiguration.load(marketId).quoteToken;
        int256[] memory baseAmounts = new int256[](1);
        baseAmounts[0] = executedBaseAmount;
        int256 annualizedBaseAmount = baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp)[0];
        IProductModule(coreProxy).propagateTakerOrder(
            accountId, ProductConfiguration.getProductId(), marketId, quoteToken, annualizedBaseAmount
        );
    }

    /**
     * @inheritdoc IProductIRSModule
     */

    function settle(uint128 accountId, uint128 marketId, uint32 maturityTimestamp) external override {
        address coreProxy = ProductConfiguration.getCoreProxyAddress();

        // check account access permissions
        IAccountModule(coreProxy).onlyAuthorized(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender);

        Portfolio.Data storage portfolio = Portfolio.load(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        int256 settlementCashflowInQuote = portfolio.settle(marketId, maturityTimestamp, poolAddress);

        address quoteToken = MarketConfiguration.load(marketId).quoteToken;

        uint128 productId = ProductConfiguration.getProductId();

        IProductModule(coreProxy).propagateCashflow(accountId, productId, quoteToken, settlementCashflowInQuote);
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
    function getAccountUnrealizedPnL(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (int256 unrealizedPnL)
    {
        Portfolio.Data storage portfolio = Portfolio.load(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        return portfolio.getAccountUnrealizedPnL(poolAddress, collateralType);
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
    function getAccountAnnualizedExposures(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (Account.Exposure[] memory exposures)
    {
        Portfolio.Data storage portfolio = Portfolio.load(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        return portfolio.getAccountAnnualizedExposures(poolAddress, collateralType);
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

        Portfolio.Data storage portfolio = Portfolio.load(accountId);
        address poolAddress = ProductConfiguration.getPoolAddress();
        portfolio.closeAccount(poolAddress, collateralType);
    }

    function configureProduct(ProductConfiguration.Data memory config) external {
        OwnableStorage.onlyOwner();

        ProductConfiguration.set(config);
        emit ProductConfigured(config);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

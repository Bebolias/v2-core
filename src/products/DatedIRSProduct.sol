//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./interfaces/IDatedIRSProduct.sol";
import "../accounts/storage/Account.sol";
import "./storage/DatedIRSPortfolio.sol";
import "./storage/DatedIRSMarketConfiguration.sol";
import "../utils/helpers/SafeCast.sol";
import "../margin-engine/storage/Collateral.sol";
import "./interfaces/IDatedIRSVAMMPool.sol";
import "../interfaces/IProductManager.sol";

/**
 * @title Dated Interest Rate Swap Product
 * @dev See IDatedIRSProduct
 */

contract DatedIRSProduct is IDatedIRSProduct {
    using DatedIRSPortfolio for DatedIRSPortfolio.Data;
    using SafeCastI256 for int256;

    address private _poolAddress;
    address private _proxy;
    uint128 private _productId;

    function initialize(address proxy, uint128 productId, address poolAddress) external {
        _proxy = proxy;
        _productId = productId;
        _poolAddress = poolAddress;
    }

    /**
     * @inheritdoc IDatedIRSProduct
     */
    function initiateTakerOrder(
        address poolAddress,
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseAmount
    )
        external
        override
        returns (int256 executedBaseAmount, int256 executedQuoteAmount)
    {
        // check if market id is valid + check there is an active pool with maturityTimestamp requested
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        IDatedIRSVAMMPool pool = IDatedIRSVAMMPool(poolAddress);
        (executedBaseAmount, executedQuoteAmount) = pool.executeDatedTakerOrder(marketId, maturityTimestamp, baseAmount);
        portfolio.updatePosition(marketId, maturityTimestamp, executedBaseAmount, executedQuoteAmount);
        IProductManager(_proxy).propagateTakerOrder(accountId, msg.sender);
    }

    /**
     * @inheritdoc IDatedIRSProduct
     */
    function initiateMakerOrder(
        address poolAddress,
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 priceLower,
        uint256 priceUpper,
        int256 requestedBaseAmount
    )
        external
        override
        returns (int256 executedBaseAmount)
    {
        IDatedIRSVAMMPool pool = IDatedIRSVAMMPool(poolAddress);
        executedBaseAmount = pool.executeDatedMakerOrder(marketId, maturityTimestamp, priceLower, priceUpper, requestedBaseAmount);

        IProductManager(_proxy).propagateMakerOrder(accountId, msg.sender);
    }
    /**
     * @inheritdoc IDatedIRSProduct
     */

    function settle(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external override {
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        int256 settlementCashflowInQuote = portfolio.settle(marketId, maturityTimestamp);

        address quoteToken = DatedIRSMarketConfiguration.load(marketId).quoteToken;

        IProductManager(_proxy).propagateCashflow(accountId, quoteToken, settlementCashflowInQuote);
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
    function getAccountUnrealizedPnL(uint128 accountId) external view override returns (int256 unrealizedPnL) {
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        return portfolio.getAccountUnrealizedPnL(_poolAddress);
    }

    /**
     * @inheritdoc IProduct
     */
    function getAccountAnnualizedExposures(uint128 accountId)
        external
        view
        override
        returns (Account.Exposure[] memory exposures)
    {
        // todo: include exposures from pools
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        return portfolio.getAccountAnnualizedExposures(_poolAddress);
    }

    /**
     * @inheritdoc IProduct
     */
    function closeAccount(uint128 accountId) external override {
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        portfolio.closeAccount(_poolAddress);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./interfaces/IBaseDatedProduct.sol";
import "../accounts/storage/Account.sol";
import "./storage/DatedIRSPortfolio.sol"

// todo: no need for base for no since not doing dated futures in the near future

/**
 * @title BaseDatedProduct abstract contract
 * @dev See IBaseDatedProduct
 */

contract DatedIRSProduct is IBaseDatedProduct {
    using Account for Account.Data;

    /**
     * @inheritdoc IBaseDatedProduct
     */
    function initiateTakerOrder(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external override {
        // check if account exists
        // check if market id is valid + check there is an active pool with maturityTimestamp requested
        // note: portfolio and account id are the same
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        (int256 executedBaseAmount, int256 executedQuoteAmount) = pool.executeTakerOrder(marketId, maturityTimestamp);
        // the storage position object can execute this
    }
    /**
     * @inheritdoc IBaseDatedProduct
     */

    function settle(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external override {}

    /**
     * @inheritdoc IBaseDatedProduct
     */
    function initiateMakerOrder(
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 priceLower,
        uint256 priceUpper
    ) external override {}

    /**
     * @inheritdoc IProduct
     */
    function name(uint128 productId) external pure override returns (string memory) {
        // todo: make this virtual
        return "Dated Product";
    }

    /**
     * @inheritdoc IProduct
     */
    function getAccountUnrealizedPnL(uint128 accountId) external view override returns (int256 unrealizedPnL) {}

    /**
     * @inheritdoc IProduct
     */
    function getAccountAnnualizedExposures(uint128 accountId)
        external
        view
        override
        returns (Account.Exposure[] memory exposures)
    {}

    /**
     * @inheritdoc IProduct
     */
    function closeAccount(uint128 accountId) external override {}

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

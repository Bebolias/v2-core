//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./interfaces/IBaseDatedProduct.sol";
import "../accounts/storage/Account.sol";

// todo: make this abstract

/**
 * @title BaseDatedProduct abstract contract
 * @dev See IBaseDatedProduct
 */

contract BaseDatedProduct is IBaseDatedProduct {
    using Account for Account.Data;

    /**
     * @inheritdoc IBaseDatedProduct
     */
    function initiateTakerOrder(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external override {
        // check if account exists
        // check if market id is valid + check there is an active pool with maturityTimestamp requested
        Account.Data storage account = Account.load(accountId);
        (int256 executedBaseAmount, int256 executedQuoteAmount) = pool.executeTakerOrder(marketId, maturityTimestamp);
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

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IProduct.sol";
import "../interfaces/IProductManager.sol";
import "./storage/Product.sol";
import "./storage/ProductCreator.sol";
import "../utils/storage/AssociatedSystem.sol";
import "../utils/helpers/ERC165Helper.sol";

/**
 * @title Protocol-wide entry point for the management of products connected to the protocol.
 * @dev See IProductManager
 */
contract ProductManager is IProductManager {
    using Product for Product.Data;
    using AssociatedSystem for AssociatedSystem.Data;

    /**
     * @inheritdoc IProductManager
     */
    function getAccountUnrealizedPnL(uint128 productId, uint128 accountId)
        external
        view
        override
        returns (int256 accountUnrealizedPnL)
    {
        accountUnrealizedPnL = Product.load(productId).getAccountUnrealizedPnL(accountId);
    }

    /**
     * @inheritdoc IProductManager
     */
    function getAccountAnnualizedExposures(uint128 productId, uint128 accountId)
        external
        view
        override
        returns (Account.Exposure[] memory exposures)
    {
        exposures = Product.load(productId).getAccountAnnualizedExposures(accountId);
    }

    /**
     * @inheritdoc IProductManager
     */
    function registerProduct(address product) external override returns (uint128 productId) {
        // todo: ensure acces to feature flag check

        if (!ERC165Helper.safeSupportsInterface(product, type(IProduct).interfaceId)) {
            revert IncorrectProductInterface(product);
        }

        productId = ProductCreator.create(product, msg.sender).id;

        emit ProductRegistered(product, productId, msg.sender);

        return productId;
    }

    /**
     * @inheritdoc IProductManager
     */

    function closeAccount(uint128 productId, uint128 accountId) external override {
        // todo: consider returning data that might be useful in the future
        // why should this function be exposed in here?
        Product.load(productId).closeAccount(accountId);
    }
}

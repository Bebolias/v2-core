//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/external/IProduct.sol";
import "../interfaces/IProductModule.sol";
import "../storage/Product.sol";
import "../storage/ProductCreator.sol";
import "../utils/modules/storage/AssociatedSystem.sol";
import "../utils/contracts//helpers/ERC165Helper.sol";
import "../utils/contracts//helpers/SafeCast.sol";

/**
 * @title Protocol-wide entry point for the management of products connected to the protocol.
 * @dev See IProductModule
 */
contract ProductModule is IProductModule {
    using Account for Account.Data;
    using Product for Product.Data;
    using SafeCastI256 for int256;
    using AssociatedSystem for AssociatedSystem.Data;
    using Collateral for Collateral.Data;

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

    // check if account exists
    // or consider calling the product maneger once to do all the checks and updates
    // todo: mark product in the account object (see python implementation for more details, solidity uses setutil though)
    // todo: interesting but account is external to this product
    // todo: process taker fees (these should also be returned)
    function propagateTakerOrder(uint128 accountId, address takerAddress) external override {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(accountId, takerAddress);
        account.imCheck();
    }

    // todo: mark product
    // todo: process maker fees (these should also be returned)
    function propagateMakerOrder(uint128 accountId, address makerAddress) external override {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(accountId, makerAddress);
        account.imCheck();
    }

    function propagateCashflow(uint128 accountId, address quoteToken, int256 amount) external override {
        Account.Data storage account = Account.load(accountId);
        if (amount > 0) {
            account.collaterals[quoteToken].increaseCollateralBalance(amount.toUint());
        } else {
            account.collaterals[quoteToken].decreaseCollateralBalance((-amount).toUint());
        }
    }
}

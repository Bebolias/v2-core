// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/errors/AccessError.sol";
import "../../interfaces/IProduct.sol";

/**
 * @title Connects external contracts that implement the `IProduct` interface to the protocol.
 *
 */
library Product {
    /**
     * @dev Thrown when a specified product is not found.
     */
    error ProductNotFound(uint128 productId);

    struct Data {
        /**
         * @dev Numeric identifier for the product. Must be unique.
         * @dev There cannot be a product with id zero (See ProductCreator.create()). Id zero is used as a null product reference.
         */
        uint128 id;
        /**
         * @dev Address for the external contract that implements the `IProduct` interface, which this Product objects connects to.
         *
         * Note: This object is how the system tracks the product. The actual product is external to the system, i.e. its own contract.
         */
        address productAddress;
        /**
         * @dev Address of the quote token in which this product settles
         */
        address quoteAddress;
        /**
         * @dev Text identifier for the product.
         *
         * Not required to be unique.
         */
        string name;
        /**
         * @dev Creator of the product, which has configuration access rights for the product.
         *
         * See onlyProductOwner.
         */
        address owner;
    }

    /**
     * @dev Returns the product stored at the specified product id.
     */
    function load(uint128 id) internal pure returns (Data storage product) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Product", id));
        assembly {
            product.slot := s
        }
    }

    /**
     * @dev Reverts if the caller is not the owner of the specified product
     */
    function onlyProductOwner(uint128 productId, address caller) internal view {
        if (Product.load(productId).owner != caller) {
            revert AccessError.Unauthorized(caller);
        }
    }

    function getAccountUnrealizedPnLInQuote(Data storage self, uint128 accountId)
        internal
        view
        returns (int256 accountUnrealizedPnLInQuote)
    {
        // todo: rename IProduct to IProduct?
        // getAccountUnrealizedPnLInQuote inside of the product aggregates the pnl for all maturities and pools
        // each product has a product address
        return IProduct(self.productAddress).getAccountUnrealizedPnLInQuote(accountId);
    }
}

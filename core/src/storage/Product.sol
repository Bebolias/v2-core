/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/errors/AccessError.sol";
import "../interfaces/external/IProduct.sol";
import "./Account.sol";

/**
 * @title Connects external contracts that implement the `IProduct` interface to the protocol.
 *
 */
library Product {
    struct Data {
        /**
         * @dev Numeric identifier for the product. Must be unique.
         * @dev There cannot be a product with id zero (See ProductCreator.create()). Id zero is used as a null product reference.
         */
        uint128 id;
        /**
         * @dev Address for the external contract that implements the `IProduct` interface, which this Product objects connects to.
         *
         * Note: This object is how the system tracks the product. The actual product is external to the system, i.e. its own
         * contract.
         */
        address productAddress;
        /**
         * @dev Text identifier for the product.
         *
         * Not required to be unique.
         */
        string name;
        /**
         * @dev Creator of the product, which has configuration access rights for the product.
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
     * @dev Reverts if the caller is not the product address of the specified product
     */
    function onlyProductAddress(uint128 productId, address caller) internal view {
        if (Product.load(productId).productAddress != caller) {
            revert AccessError.Unauthorized(caller);
        }
    }

    /**
     * @dev in context of interest rate swaps, base refers to scaled variable tokens (e.g. scaled virtual aUSDC)
     * @dev in order to derive the annualized exposure of base tokens in quote terms (i.e. USDC), we need to
     * first calculate the (non-annualized) exposure by multiplying the baseAmount by the current liquidity index of the
     * underlying rate oracle (e.g. aUSDC lend rate oracle)
     */
    function baseToAnnualizedExposure(
        Data storage self,
        int256[] memory baseAmounts,
        uint128 marketId,
        uint32 maturityTimestamp
    ) internal view returns (int256[] memory exposures) {
        return IProduct(self.productAddress).baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp);
    }

    /**
     * @dev Returns taker exposures alongside maker exposures for the lower and upper bounds of the maker's range
     */
    function getAccountTakerAndMakerExposures(Data storage self, uint128 accountId, address collateralType)
        internal
        view
        returns (Account.Exposure[] memory takerExposures, Account.Exposure[] memory makerExposuresLower, Account.Exposure[] memory makerExposuresUpper)
    {
        return IProduct(self.productAddress).getAccountTakerAndMakerExposures(accountId, collateralType);
    }

    /**
     * @dev The product at self.productAddress is expected to close filled and unfilled positions for all maturities and pools
     */
    function closeAccount(Data storage self, uint128 accountId, address collateralType) internal {
        IProduct(self.productAddress).closeAccount(accountId, collateralType);
    }
}

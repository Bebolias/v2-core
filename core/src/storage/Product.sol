// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/util-contracts/src/errors/AccessError.sol";
import "../interfaces/external/IProduct.sol";
import "./Account.sol";
import { UD60x18, ud} from "@prb/math/UD60x18.sol";
import { SD59x18, unwrap, sd } from "@prb/math/SD59x18.sol";

/**
 * @title Connects external contracts that implement the `IProduct` interface to the protocol.
 *
 */
library Product {
    using { unwrap } for SD59x18;

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
     * @dev The product at self.productAddress is expected to aggregate the pnl for a given account in all maturities and pools
     * @dev note, given that the account only supports single-token mode, the unrealised pnl is expected to be in terms of the
     * settlement token of the account, i.e. all the positions used in the unrealised pnl calculation should settle/quote in a token
     * that matches the settlement token of the account.
     */
    function getAccountUnrealizedPnL(Data storage self, uint128 accountId, address collateralType) 
        internal view returns (int256 accountUnrealizedPnL) 
    {
        return IProduct(self.productAddress).getAccountUnrealizedPnL(accountId, collateralType).unwrap();
    }

    /**
     * @dev in context of interest rate swaps, base refers to scaled variable tokens (e.g. scaled virtual aUSDC)
     * @dev in order to derive the annualized exposure of base tokens in quote terms (i.e. USDC), we need to
     * first calculate the (non-annualized) exposure by multiplying the baseAmount by the current liquidity index of the
     * underlying rate oracle (e.g. aUSDC lend rate oracle)
     */
    function baseToAnnualizedExposure(Data storage self, int256[] memory baseAmounts, uint128 marketId, uint32 maturityTimestamp) 
        external view returns (int256[] memory exposures) 
    {
        // todo: introduce PRBMath in core & remove this bit
        SD59x18[] memory baseAmountsSD = new SD59x18[](baseAmounts.length);
        for (uint i = 0; i < baseAmounts.length; i++) {
            baseAmountsSD[i] = sd(baseAmounts[i]);
        }
        SD59x18[] memory resultSD =  IProduct(self.productAddress).baseToAnnualizedExposure(baseAmountsSD, marketId, uint32(maturityTimestamp));

        int256[] memory result = new int256[](resultSD.length);
        for (uint i = 0; i < resultSD.length; i++) {
            result[i] = unwrap(resultSD[i]);
        }
        return result;
    }

    /**
     * @dev The product at self.productAddress is expected to aggregate filled and 
     * @dev unfilled notionals for all maturities and pools
     * note: needs to be in terms of the collateralType token of the account given currently 
     * note only supporting single-token mode
     */
    function getAccountAnnualizedExposures(
        Data storage self,
        uint128 accountId,
        address collateralType
    )
        internal
        returns (Account.Exposure[] memory exposures)
    {
        return IProduct(self.productAddress).getAccountAnnualizedExposures(accountId, collateralType);
    }

    /**
     * @dev The product at self.productAddress is expected to close filled and unfilled positions for all maturities and pools
     */
    function closeAccount(Data storage self, uint128 accountId, address collateralType) internal {
        IProduct(self.productAddress).closeAccount(accountId, collateralType);
    }
}

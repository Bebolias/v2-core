//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/core/src/interfaces/external/IProduct.sol";
import "../storage/ProductConfiguration.sol";

/// @title Interface of a dated irs product
interface IProductIRSModule is IProduct {
    event ProductConfigured(ProductConfiguration.Data config);

    // process taker and maker orders & single pool

    /**
     * @notice Returns the address that owns a given account, as recorded by the protocol.
     * @param accountId Id of the account that wants to settle
     * @param marketId Id of the market in which the account wants to settle (e.g. 1 for aUSDC lend)
     * @param maturityTimestamp Maturity timestamp of the market in which the account wants to settle
     */
    function settle(uint128 accountId, uint128 marketId, uint32 maturityTimestamp) external;

    /**
     * @notice Initiates a taker order for a given account by consuming liquidity provided by the pool connected to this product
     * @dev Initially a single pool is connected to a single product, however, that doesn't need to be the case in the future
     * @param accountId Id of the account that wants to initiate a taker order
     * @param marketId Id of the market in which the account wants to initiate a taker order (e.g. 1 for aUSDC lend)
     * @param maturityTimestamp Maturity timestamp of the market in which the account wants to initiate a taker order
     * @param baseAmount Amount of notional that the account wants to trade in either long (+) or short (-) direction depending on
     * sign
     */
    function initiateTakerOrder(
        uint128 accountId,
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 baseAmount
    )
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);
}

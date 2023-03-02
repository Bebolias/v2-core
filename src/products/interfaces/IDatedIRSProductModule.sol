//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../core/interfaces/external/IProduct.sol";

/// @title Interface of a dated irs product
interface IDatedIRSProductModule is IProduct {
    // process taker and maker orders & single pool

    /**
     * @notice Returns the address that owns a given account, as recorded by the protocol.
     * @param accountId Id of the account that wants to settle
     * @param marketId Id of the market in which the account wants to settle (e.g. 1 for aUSDC lend)
     * @param maturityTimestamp Maturity timestamp of the market in which the account wants to settle
     */
    function settle(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external;

    /**
     * @notice Initiates a taker order for a given account by consuming liquidity provided by the pool connected to this product
     * @dev Initially a single pool is connected to a single product, however, that doesn't need to be the case in the future
     * @param poolAddress Address of the pool implementation that acts as the counterparty and pricer to the taker order initiated
     * by accountId
     * @param accountId Id of the account that wants to initiate a taker order
     * @param marketId Id of the market in which the account wants to initiate a taker order (e.g. 1 for aUSDC lend)
     * @param maturityTimestamp Maturity timestamp of the market in which the account wants to initiate a taker order
     * @param baseAmount Amount of notional that the account wants to trade in either long (+) or short (-) direction depending on
     * sign
     */
    function initiateTakerOrder(
        address poolAddress,
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseAmount
    )
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);

    /**
     * @notice Initiates a maker order for a given account by providing liquidity to the pool connected to this product
     * @dev Initially a single pool is connected to a single product, however, that doesn't need to be the case in the future
     * @param accountId Id of the account that wants to initiate a taker order
     * @param marketId Id of the market in which the account wants to initiate a taker order (e.g. 1 for aUSDC lend)
     * @param maturityTimestamp Maturity timestamp of the market in which the account wants to initiate a taker order
     * @param priceLower Lower price associated with the maker order (e.g. in context of a vamm, lower price of a range liquidity
     * order)
     * @param priceUpper Upper price associated with the maker order (e.g. in context of a vamm, upper price of a range liquidity
     * order)
     */
    function initiateMakerOrder(
        address poolAddress,
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 priceLower,
        uint256 priceUpper,
        int256 notionalAmount
    )
        external
        returns (int256 executedBaseAmount);
}

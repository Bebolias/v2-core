// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./IPool.sol";

/**
 * @title Dated Interest Rate Swap VAMM Pool
 * @dev Implementation of DatedIRSVAMMPool is in a separate repo
 * @dev Can be thought of as a vamm router that can take marketId + maturityTimestamp pair and route the order via the relevant vamm
 * @dev See IVAMMPoolModule
 */

interface IVAMMPoolModule is IPool {
    /**
     * @notice Executes a dated maker order against a vamm that provided liquidity to a given marketId & maturityTimestamp pair
     * @param marketId Id of the market in which the lp wants to provide liqudiity
     * @param maturityTimestamp Timestamp at which a given market matures
     * @param fixedRateLower Lower Fixed Rate of the range order
     * @param fixedRateUpper Upper Fixed Rate of the range order
     * @param requestedBaseAmount Requested amount of notional provided to a given vamm in terms of the virtual base tokens of the
     * market
     * @param executedBaseAmount Executed amount of notional provided to a given vamm in terms of the virtual base tokens of the
     * market
     */
    function executeDatedMakerOrder(
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 fixedRateLower,
        uint256 fixedRateUpper,
        int256 requestedBaseAmount
    )
        external
        returns (int256 executedBaseAmount);

    /**
     * @notice Get dated irs gwap for the purposes of unrealized pnl calculation in the portfolio (see Portfolio.sol)
     * @param marketId Id of the market for which we want to retrieve the dated irs gwap
     * @param maturityTimestamp Timestamp at which a given market matures
     * @return datedIRSGwap Geometric Time Weighted Average Fixed Rate
     *  // todo: note, currently the product (and the core) are offloading the twap lookback widnow setting to the vamm pool
     *  // however, intuitively it feels like the twap lookback window is quite an important risk parameter that arguably
     *  // should sit in the MarketRiskConfiguration.sol within the core where it is made possible for the owner
     *  // to specify custom twap lookback windows for different productId/marketId combinations
     */
    function getDatedIRSGwap(uint128 marketId, uint256 maturityTimestamp) external view returns (uint256 datedIRSGwap);
}

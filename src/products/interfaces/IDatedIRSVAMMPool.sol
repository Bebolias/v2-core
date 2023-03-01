// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./IPool.sol";

/**
 * @title Dated Interest Rate Swap VAMM Pool
 * @dev Implementation of DatedIRSVAMMPool is in a separate repo
 * @dev Can be thought of as a vamm router that can take marketId + maturityTimestamp pair and route the order via the relevant vamm
 * @dev See IDatedIRSVAMMPool
 */

interface IDatedIRSVAMMPool is IPool {
    /**
     * @notice Executes a dated maker order against a vamm that provided liquidity to a given marketId & maturityTimestamp pair
     * @param marketId Id of the market in which the lp wants to provide liqudiity
     * @param maturityTimestamp Timestamp at which a given market matures
     * @param fixedRateLower Lower Fixed Rate of the range order
     * @param fixedRateUpper Upper Fixed Rate of the range order
     * @param requestedBaseAmount Requested amount of notional provided to a given vamm in terms of the virtual base tokens of the market
     * @param executedBaseAmount Executed amount of notional provided to a given vamm in terms of the virtual base tokens of the market
     */
    function executeDatedMakerOrder(
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 fixedRateLower,
        uint256 fixedRateUpper,
        int256 requestedBaseAmount
    ) external returns (int256 executedBaseAmount);
}

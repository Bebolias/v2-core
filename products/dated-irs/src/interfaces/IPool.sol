// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/core/src/utils/contracts/interfaces/IERC165.sol";

/// @title Interface a Pool needs to adhere.
interface IPool is IERC165 {
    /// @notice returns a human-readable name for a given pool
    function name(uint128 poolId) external view returns (string memory);

    /// @dev note, a pool needs to have this interface to enable account closures initiated by products
    /// @dev in the future -> executePerpetualTakerOrder(uint128 marketId, int256 baseAmount)
    /// for products that don't have maturities
    function executeDatedTakerOrder(
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseAmount
    )
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);

    function getAccountFilledBalances(
        uint128 marketId,
        uint256 maturityTimestamp,
        uint128 accountId
    )
        external
        view
        returns (int256 baseBalancePool, int256 quoteBalancePool);

    function getAccountUnfilledBases(
        uint128 marketId,
        uint256 maturityTimestamp,
        uint128 accountId
    )
        external
        view
        returns (int256 unfilledBaseLong, int256 unfilledBaseShort);

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

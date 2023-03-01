// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/interfaces/IERC165.sol";

/// @title Interface a Pool needs to adhere.
interface IPool is IERC165 {
    /// @notice returns a human-readable name for a given pool
    function name(uint128 poolId) external view returns (string memory);

    /// @dev note, a pool needs to have this interface to enable account closures initiated by products
    /// @dev in the future -> executePerpetualTakerOrder(uint128 marketId, int256 baseAmount)
    /// for products that don't have maturities
    function executeDatedTakerOrder(uint128 marketId, uint256 maturityTimestamp, int256 baseAmount)
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);

    function getAccountFilledBalances(uint128 marketId, uint256 maturityTimestamp, uint128 accountId)
        external
        view
        returns (int256 baseBalancePool, int256 quoteBalancePool);

    function getAccountUnfilledBases(uint128 marketId, uint256 maturityTimestamp, uint128 accountId)
        external
        view
        returns (int256 unfilledBaseLong, int256 unfilledBaseShort);
}

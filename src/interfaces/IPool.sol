// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../utils/interfaces/IERC165.sol";

/// @title Interface a Product needs to adhere.
interface IPool is IERC165 {
    /// @notice returns a human-readable name for a given pool
    function name(uint128 poolId) external view returns (string memory);

    function executeTakerOrder(uint128 marketId, uint256 maturityTimestamp, int256 notionalAmount)
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);

    function executeMakerOrder(
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 priceLower,
        uint256 priceUpper,
        int256 notionalAmount
    ) external returns (int256 executedBaseAmount);
}

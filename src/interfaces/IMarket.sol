// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/// @title Interface a Market needs to adhere.
interface IMarket {
    // get account annualized filled and unfilled notionals (base in quote terms)

    /// @notice returns a human-readable name for a given market
    function name(uint128 marketId) external view returns (string memory);

    /// @notice returns the unrealized pnl in quote token terms for account
    function getAccountUnrealizedPnLInQuote(uint128 accountId) external returns (int256);

    /// @notice returns annualized filled notional, annualized unfilled notional long, annualized unfilled notional short
    function getAccountAnnualizedFilledUnfilledNotionalsInQuote(uint128 accountId)
        external
        returns (int256, uint256, uint256);

    /// @notice attempts to close all the unfilled and filled positions of a given account in the market
    // todo: think about this, what if we collapse the maturity into the marketId
    function closeAccount(uint128 accountId) external;
}

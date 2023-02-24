// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../utils/interfaces/IERC165.sol";

/// @title Interface a Product needs to adhere.
interface IProduct is IERC165 {
    /// @notice returns a human-readable name for a given product
    function name(uint128 marketId) external view returns (string memory);

    /// @notice returns the unrealized pnl in quote token terms for account
    function getAccountUnrealizedPnLInQuote(uint128 accountId) external view returns (int256);

    /// @notice returns annualized filled notional, annualized unfilled notional long, annualized unfilled notional short
    function getAccountAnnualizedFilledUnfilledNotionalsInQuote(uint128 accountId)
        external
        view
        returns (int256, uint256, uint256);

    // state-changing functions

    /// @notice attempts to close all the unfilled and filled positions of a given account in the product
    // if there are multiple maturities in which the account has active positions, the product is expected to close
    // all of them
    function closeAccount(uint128 accountId) external;
}

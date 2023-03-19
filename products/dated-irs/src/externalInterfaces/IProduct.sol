// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../utils/contracts/src/interfaces/IERC165.sol";
import "./Account.sol";

/// @title Interface a Product needs to adhere.
interface IProduct is IERC165 {
    /// @notice returns a human-readable name for a given product
    function name() external view returns (string memory);

    /// @notice returns the unrealized pnl in quote token terms for account
    function getAccountUnrealizedPnL(uint128 accountId) external view returns (int256 unrealizedPnL);

    /// @notice returns annualized filled notional, annualized unfilled notional long, annualized unfilled notional short
    function getAccountAnnualizedExposures(uint128 accountId) external returns (Account.Exposure[] memory exposures);

    // state-changing functions

    /// @notice attempts to close all the unfilled and filled positions of a given account in the product
    // if there are multiple maturities in which the account has active positions, the product is expected to close
    // all of them
    function closeAccount(uint128 accountId) external;
}

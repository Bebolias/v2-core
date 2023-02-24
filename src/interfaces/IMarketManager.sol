// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title System-wide entry point for the management of markets connected to the protocol.
 */
interface IMarketManager {
    /**
     * @notice Thrown when an attempt to register a market that does not conform to the IMarket interface is made.
     */
    error IncorrectMarketInterface(address market);

    /**
     * @notice Emitted when a new market is registered in the protocol.
     * @param market The address of the market that was registered in the system.
     * @param marketId The id with which the market was registered in the system.
     * @param sender The account that trigger the registration of the market and also the owner of the market
     */
    event MarketRegistered(address indexed market, uint128 indexed marketId, address indexed sender);

    /// @notice returns the unrealized pnl in quote token terms for account
    function getAccountUnrealizedPnLInQuote(uint128 marketId, uint128 accountId) external view returns (int256);

    /// @notice returns annualized filled notional, annualized unfilled notional long, annualized unfilled notional short
    function getAccountAnnualizedFilledUnfilledNotionalsInQuote(uint128 marketId, uint128 accountId)
        external
        view
        returns (int256, uint256, uint256);

    // state changing functions

    /**
     * @notice Connects a market to the system.
     * @dev Creates a Market object to track the market, and returns the newly created market id.
     * @param market The address of the market that is to be registered in the system.
     * @return newMarketId The id with which the market will be registered in the system.
     */
    function registerMarket(address market) external returns (uint128 newMarketId);

    /// @notice attempts to close all the unfilled and filled positions of a given account in a given market (marketId)
    function closeAccount(uint128 marketId, uint128 accountId) external;
}

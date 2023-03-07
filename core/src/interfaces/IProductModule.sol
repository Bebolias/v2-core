// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../storage/Account.sol";

/**
 * @title System-wide entry point for the management of products connected to the protocol.
 */
interface IProductModule {
    /**
     * @notice Thrown when an attempt to register a product that does not conform to the IProduct interface is made.
     */
    error IncorrectProductInterface(address product);

    /**
     * @notice Emitted when a new product is registered in the protocol.
     * @param product The address of the product that was registered in the system.
     * @param productId The id with which the product was registered in the system.
     * @param sender The account that trigger the registration of the product and also the owner of the product
     */
    event ProductRegistered(address indexed product, uint128 indexed productId, address indexed sender);

    /// @notice returns the unrealized pnl in quote token terms for account
    function getAccountUnrealizedPnL(uint128 productId, uint128 accountId) external returns (int256);

    /// @notice returns annualized filled notional, annualized unfilled notional long, annualized unfilled notional short
    function getAccountAnnualizedExposures(
        uint128 productId,
        uint128 accountId
    )
        external
        returns (Account.Exposure[] memory exposures);

    // state changing functions

    /**
     * @notice Connects a product to the system.
     * @dev Creates a product object to track the product, and returns the newly created product id.
     * @param product The address of the product that is to be registered in the system.
     * @return newProductId The id with which the product will be registered in the system.
     */
    function registerProduct(address product, string memory name) external returns (uint128 newProductId);

    /// @notice attempts to close all the unfilled and filled positions of a given account in a given product (productId)
    function closeAccount(uint128 productId, uint128 accountId) external;

    function propagateTakerOrder(uint128 accountId, address takerAddress) external;

    function propagateMakerOrder(uint128 accountId, address makerAddress) external;

    function propagateCashflow(uint128 accountId, address quoteToken, int256 amount) external;
}

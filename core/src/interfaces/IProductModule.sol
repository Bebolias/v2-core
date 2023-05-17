pragma solidity >=0.8.19;

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
     * @param sender The account that trigger the registration of the product and also the owner of the product.
     * @param blockTimestamp The current block timestamp.
     */
    event ProductRegistered(
        address indexed product, uint128 indexed productId, string name, address indexed sender, uint256 blockTimestamp
    );

    /**
     * @notice Emitted when account token with id `accountId` deals with new product.
     * @param accountId The id of the account.
     * @param productId The id of the product.
     * @param blockTimestamp The current block timestamp.
     */
    event NewActiveProduct(uint128 indexed accountId, uint128 indexed productId, uint256 blockTimestamp);

    /**
     * @notice Emitted when account token with id `accountId` is closed.
     * @param accountId The id of the account.
     * @param productId The id of the product.
     * @param collateralType The address of the collateral token.
     * @param blockTimestamp The current block timestamp.
     */
    event AccountClosed(
        uint128 indexed accountId, uint128 indexed productId, address collateralType, uint256 blockTimestamp
    );

    /**
     * @notice Emitted when a taker order of the account token with id `accountId` is propagated by the product.
     * @param accountId The id of the account.
     * @param productId The id of the product.
     * @param marketId The id of the market.
     * @param collateralType The address of the collateral.
     * @param annualizedNotional The annualized notional of the order.
     * @param fee The amount of fees paid for the order.
     * @param blockTimestamp The current block timestamp.
     */
    event TakerOrderPropagated(
        uint128 indexed accountId,
        uint128 indexed productId,
        uint128 indexed marketId,
        address collateralType,
        int256 annualizedNotional,
        uint256 fee,
        uint256 blockTimestamp
    );

    /**
     * @notice Emitted when a maker order of the account token with id `accountId` is propagated by the product.
     * @param accountId The id of the account.
     * @param productId The id of the product.
     * @param marketId The id of the market.
     * @param collateralType The address of the collateral.
     * @param annualizedNotional The annualized notional of the order.
     * @param fee The amount of fees paid for the order.
     * @param blockTimestamp The current block timestamp.
     */
    event MakerOrderPropagated(
        uint128 indexed accountId,
        uint128 indexed productId,
        uint128 indexed marketId,
        address collateralType,
        int256 annualizedNotional,
        uint256 fee,
        uint256 blockTimestamp
    );

    /**
     * @notice Emitted when cashflow is propagated by the product.
     * @param accountId The id of the account.
     * @param productId The id of the product.
     * @param collateralType The address of the collateral.
     * @param amount The cashflow amount.
     * @param blockTimestamp The current block timestamp.
     */
    event CashflowPropagated(
        uint128 indexed accountId,
        uint128 indexed productId,
        address collateralType,
        int256 amount,
        uint256 blockTimestamp
    );

    /// @notice returns the unrealized pnl in quote token terms for account
    function getAccountUnrealizedPnL(uint128 productId, uint128 accountId, address collateralType)
        external
        returns (int256);

    /// @notice returns annualized filled notional, annualized unfilled notional long, annualized unfilled notional short
    function getAccountAnnualizedExposures(uint128 productId, uint128 accountId, address collateralType)
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
    function closeAccount(uint128 productId, uint128 accountId, address collateralType) external;

    // todo: is annualizedNotional supposed to be unsigned?
    function propagateTakerOrder(
        uint128 accountId,
        uint128 productId,
        uint128 marketId,
        address collateralType,
        int256 annualizedNotional
    ) external returns (uint256 fee);

    // todo: is annualizedNotional supposed to be unsigned?
    function propagateMakerOrder(
        uint128 accountId,
        uint128 productId,
        uint128 marketId,
        address collateralType,
        int256 annualizedNotional
    ) external returns (uint256 fee);

    function propagateCashflow(uint128 accountId, uint128 productId, address collateralType, int256 amount) external;
}

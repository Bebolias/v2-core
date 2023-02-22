//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Liquidation Engine interface
 */
interface ILiquidationEngine {
    /**
     * @notice Thrown when attempting to liquidate an account that is not eligible for liquidation.
     */
    // todo: rename and add arguments to the error
    error IneligibleForLiquidation();

    /**
     * @notice Emitted when an account is liquidated.
     * @param accountId The id of the account that was liquidated.
     * @param collateralType The collateral type of the account that was liquidated
     * @param liquidationData Relevant liquidation data (e.g. liquidator reward amount)
     * @param liquidateAsAccountId Account id that will receive the rewards from the liquidation.
     * @param sender The address of the account that is triggering the liquidation.
     */
    event Liquidation(
        uint128 indexed accountId,
        uint128 indexed poolId,
        address indexed collateralType,
        LiquidationData liquidationData,
        uint128 liquidateAsAccountId,
        address sender
    );

    /**
     * @notice Data structure that holds liquidation information, used in events and in return statements.
     */
    struct LiquidationData {
        /**
         * @dev The amount rewarded in the liquidation.
         */
        uint256 amountRewarded;
    }

    /**
     * @notice Liquidates an account
     * @param accountId The id of the account that is being liquidated
     * @param liquidateAsAccountId Account id that will receive the rewards from the liquidation.
     * @return liquidationData Information about the position that was liquidated.
     */
    function liquidate(uint128 accountId, uint128 liquidateAsAccountId)
        external
        returns (LiquidationData memory liquidationData);

    /**
     * @notice Determines whether a specified account is liquidatable
     * @param accountId The id of the account that is being queried for liquidation.
     * @return canLiquidate A boolean with the response to the query.
     */
    function isAccountLiquidatable(uint128 accountId) external returns (bool canLiquidate);

    function getAccountMarginRequirements(uint128 accountId)
        external
        view
        returns (uint256 initialMarginRequirementD18, uint256 liquidationMarginRequirementD18);

    function isAccountIMSatisfied(uint128 accountID) external view returns (bool isIMSatisfied);
}

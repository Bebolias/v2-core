//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Liquidation Engine interface
 */
interface ILiquidationModule {
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
     * @param liquidatedAccountId The id of the account that is being liquidated
     * @param liquidatorAccountId Account id that will receive the rewards from the liquidation.
     * @return liquidatorRewardAmount Liquidator reward amount in terms of the account's settlement token
     */
    function liquidate(
        uint128 liquidatedAccountId,
        uint128 liquidatorAccountId
    )
        external
        returns (uint256 liquidatorRewardAmount);
}

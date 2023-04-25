//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

/**
 * @title Liquidation Engine interface
 */
interface ILiquidationModule {
    /**
     * @dev Thrown when an account is not liquidatable but liquidation is triggered on it.
     */
    error AccountNotLiquidatable(uint128 accountId);

    /**
     * @dev Thrown when an account exposure is not reduced when liquidated.
     */
    error AccountExposureNotReduced(uint128 accountId, uint256 imPreClose, uint256 imPostClose);

    /**
     * @dev Thrown when a liquidation uses the liquidation booster but the account
     * is not fully liquidated.
     * todo: liquidity minted for liquidation
     */
    error PartialLiquidationNotIncentivized(uint128 accountId, uint256 imPreClose, uint256 imPostClose);

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
    function liquidate(uint128 liquidatedAccountId, uint128 liquidatorAccountId, address collateralType)
        external
        returns (uint256 liquidatorRewardAmount);
}

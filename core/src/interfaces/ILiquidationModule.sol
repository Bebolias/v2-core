/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
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
    error AccountExposureNotReduced(
        uint128 accountId,
        uint256 imPreClose,
        uint256 imPostClose,
        uint256 highestUnrealizedLossPreClose,
        uint256 highestUnrealizedLossPostClose
    );

    /**
     * @dev Thrown when a liquidation uses the liquidation booster but the account
     * is not fully liquidated.
     * todo: liquidity minted for liquidation (AN) - not sure what this means but I think you've originally
     *   written this code so you might know if anything needs to be remidiated here or we can safely remove it.
     */
    error PartialLiquidationNotIncentivized(uint128 accountId, uint256 imPreClose, uint256 imPostClose);

    /**
     * @notice Emitted when an account is liquidated.
     * @param liquidatedAccountId The id of the account that was liquidated.
     * @param collateralType The collateral type of the account that was liquidated
     * @param liquidatorAccountId Account id that will receive the rewards from the liquidation.
     * @param liquidatorRewardAmount The liquidator reward amount
     * @param sender The address that triggers the liquidation.
     * @param blockTimestamp The current block timestamp.
     */
    event Liquidation(
        uint128 indexed liquidatedAccountId,
        address indexed collateralType,
        address sender,
        uint128 liquidatorAccountId,
        uint256 liquidatorRewardAmount,
        uint256 imPreClose,
        uint256 imPostClose,
        uint256 highestUnrealizedLossPreClose,
        uint256 highestUnrealizedLossPostClose,
        uint256 blockTimestamp
    );

    /**
     * @notice Checks if an account is liquidatable
     * @param accountId The id of the account that is being checked
     * @param collateralType The collateral type of the account that is being checked
     * @return liquidatable True if the account is liquidatable
     * @return initialMarginRequirement The initial margin requirement of the account
     * @return liquidationMarginRequirement The liquidation margin requirement of the account
     * @return highestUnrealizedLoss The highest unrealized loss of the account
     */
    function isLiquidatable(uint128 accountId, address collateralType) external view returns (
        bool liquidatable,
        uint256 initialMarginRequirement,
        uint256 liquidationMarginRequirement,
        uint256 highestUnrealizedLoss
    );

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

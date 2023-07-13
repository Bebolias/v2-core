/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "../storage/Account.sol";
import "../storage/ProtocolRiskConfiguration.sol";
import "../storage/CollateralConfiguration.sol";
import "@voltz-protocol/util-contracts/src/errors/ParameterError.sol";
import "../interfaces/ILiquidationModule.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "../storage/Collateral.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";

import {mulUDxUint} from "@voltz-protocol/util-contracts/src/helpers/PrbMathHelper.sol";

/**
 * @title Module for liquidated accounts
 * @dev See ILiquidationModule
 */

contract LiquidationModule is ILiquidationModule {
    using ProtocolRiskConfiguration for ProtocolRiskConfiguration.Data;
    using CollateralConfiguration for CollateralConfiguration.Data;
    using Account for Account.Data;
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;
    using Collateral for Collateral.Data;

    bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";

    function extractLiquidatorReward(
        uint128 liquidatedAccountId,
        address collateralType,
        uint256 coverPreClose,
        uint256 coverPostClose
    ) internal returns (uint256 liquidatorRewardAmount) {
        Account.Data storage account = Account.load(liquidatedAccountId);

        UD60x18 liquidatorRewardParameter = ProtocolRiskConfiguration.load().liquidatorRewardParameter;
        uint256 liquidationBooster = CollateralConfiguration.load(collateralType).liquidationBooster;

        if (mulUDxUint(liquidatorRewardParameter, coverPreClose) >= liquidationBooster) {
            liquidatorRewardAmount = mulUDxUint(liquidatorRewardParameter, coverPreClose - coverPostClose);
            account.collaterals[collateralType].decreaseCollateralBalance(liquidatorRewardAmount);
            emit Collateral.CollateralUpdate(
                liquidatedAccountId, collateralType, -liquidatorRewardAmount.toInt(), block.timestamp
            );
        } else {
            if (coverPostClose != 0) {
                revert PartialLiquidationNotIncentivized(liquidatedAccountId, coverPreClose, coverPostClose);
            }

            liquidatorRewardAmount = liquidationBooster;
            account.collaterals[collateralType].decreaseLiquidationBoosterBalance(liquidatorRewardAmount);
            emit Collateral.LiquidatorBoosterUpdate(
                liquidatedAccountId, collateralType, -liquidatorRewardAmount.toInt(), block.timestamp
            );
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidate(uint128 liquidatedAccountId, uint128 liquidatorAccountId, address collateralType)
        external
        returns (uint256 liquidatorRewardAmount)
    {
        // todo: needs review alongside Artur A + IR flagged a potential issue with the liquidation flow
        FeatureFlag.ensureAccessToFeature(_GLOBAL_FEATURE_FLAG);
        Account.Data storage account = Account.exists(liquidatedAccountId);
        (bool liquidatable, uint256 imPreClose,,uint256 highestUnrealizedLossPreClose) = account.isLiquidatable(collateralType);

        if (!liquidatable) {
            revert AccountNotLiquidatable(liquidatedAccountId);
        }

        account.closeAccount(collateralType);
        (uint256 imPostClose,,uint256 highestUnrealizedLossPostClose) = 
            account.getMarginRequirementsAndHighestUnrealizedLoss(collateralType);

        if (imPreClose + highestUnrealizedLossPreClose <= imPostClose + highestUnrealizedLossPostClose) {
            revert AccountExposureNotReduced(
                liquidatedAccountId,
                imPreClose,
                imPostClose,
                highestUnrealizedLossPreClose,
                highestUnrealizedLossPostClose
            );
        }

        liquidatorRewardAmount = extractLiquidatorReward(
            liquidatedAccountId,
            collateralType,
            imPreClose + highestUnrealizedLossPreClose,
            imPostClose+highestUnrealizedLossPostClose
        );

        Account.Data storage liquidatorAccount = Account.exists(liquidatorAccountId);
        liquidatorAccount.collaterals[collateralType].increaseCollateralBalance(liquidatorRewardAmount);
        emit Collateral.CollateralUpdate(
            liquidatorAccountId, collateralType, liquidatorRewardAmount.toInt(), block.timestamp
        );

        emit Liquidation(
            liquidatedAccountId,
            collateralType,
            msg.sender,
            liquidatorAccountId,
            liquidatorRewardAmount,
            imPreClose,
            imPostClose,
            highestUnrealizedLossPreClose,
            highestUnrealizedLossPostClose,
            block.timestamp
        );
    }
}

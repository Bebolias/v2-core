//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../storage/Account.sol";
import "../storage/ProtocolRiskConfiguration.sol";
import "@voltz-protocol/util-contracts/src/errors/ParameterError.sol";
import "../interfaces/ILiquidationModule.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "../storage/Collateral.sol";

/**
 * @title Module for liquidated accounts
 * @dev See ILiquidationModule
 */

contract LiquidationModule is ILiquidationModule {
    using ProtocolRiskConfiguration for ProtocolRiskConfiguration.Data;
    using Account for Account.Data;
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;
    using Collateral for Collateral.Data;

    /**
     * @dev Thrown when an account is not liquidatable but liquidation is triggered on it.
     */
    error AccountNotLiquidatable(uint128 accountId);

    /**
     * @dev Thrown when an account exposure is not reduced when liquidated.
     */
    error AccountExposureNotReduced(uint128 accountId, uint256 imPreClose, uint256 imPostClose);

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidate(
        uint128 liquidatedAccountId,
        uint128 liquidatorAccountId
    )
        external
        returns (uint256 liquidatorRewardAmount)
    {
        Account.Data storage account = Account.exists(liquidatedAccountId);
        address liquidatorRewardToken = account.settlementToken;
        (bool liquidatable, uint256 imPreClose,) = account.isLiquidatable();

        if (!liquidatable) {
            revert AccountNotLiquidatable(liquidatedAccountId);
        }

        account.closeAccount();
        (uint256 imPostClose,) = account.getMarginRequirements();

        if (imPreClose <= imPostClose) {
            revert AccountExposureNotReduced(liquidatedAccountId, imPreClose, imPostClose);
        }

        // todo: liquidator deposit logic vs. alternatives (P1)

        liquidatorRewardAmount = (imPreClose - imPostClose) * ProtocolRiskConfiguration.load().liquidatorRewardParameter / 1e18;
        Account.Data storage liquidatorAccount = Account.exists(liquidatorAccountId);

        account.collaterals[liquidatorRewardToken].decreaseCollateralBalance(liquidatorRewardAmount);
        liquidatorAccount.collaterals[liquidatorRewardToken].increaseCollateralBalance(liquidatorRewardAmount);
    }
}

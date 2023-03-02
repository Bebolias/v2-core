//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../storage/Account.sol";
import "../storage/ProtocolRiskConfiguration.sol";
import "../../utils/errors/ParameterError.sol";
import "../interfaces/ILiquidationModule.sol";
import "../../utils/helpers/SafeCast.sol";
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
     * @inheritdoc ILiquidationModule
     */
    function liquidate(
        uint128 liquidatedAccountId,
        uint128 liquidatorAccountId
    )
        external
        returns (uint256 liquidatorRewardAmount)
    {
        Account.exists(liquidatedAccountId);
        Account.Data storage account = Account.load(liquidatedAccountId);
        address liquidatorRewardToken = account.settlementToken;
        (bool liquidatable, uint256 imPreClose,) = account.isLiquidatable();

        if (!liquidatable) {
            // todo: revert
        }
        account.closeAccount();
        (uint256 imPostClose,) = account.getMarginRequirements();
        int256 deltaIM = imPostClose.toInt() - imPreClose.toInt();

        if (deltaIM <= 0) {
            // todo: revert
        }

        // todo: liquidator deposit logic vs. alternatives (P1)

        liquidatorRewardAmount = deltaIM.toUint() * ProtocolRiskConfiguration.load().liquidatorRewardParameter;
        Account.Data storage liquidatorAccount = Account.load(liquidatorAccountId);

        account.collaterals[liquidatorRewardToken].decreaseCollateralBalance(liquidatorRewardAmount);
        liquidatorAccount.collaterals[liquidatorRewardToken].increaseCollateralBalance(liquidatorRewardAmount);
    }
}

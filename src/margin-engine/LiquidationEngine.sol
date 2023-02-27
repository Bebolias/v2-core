//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../accounts/storage/Account.sol";
import "../utils/errors/ParameterError.sol";
import "../interfaces/ILiquidationEngine.sol";

/**
 * @title Module for liquidated accounts
 * @dev See ILiquidationEngine
 */

contract LiquidationEngine is ILiquidationEngine {
    /**
     * @inheritdoc ILiquidationEngine
     */
    function liquidate(uint128 accountId, uint128 liquidateAsAccountId)
        external
        returns (LiquidationData memory liquidationData)
    {}

    /**
     * @inheritdoc ILiquidationEngine
     */
    function isAccountLiquidatable(uint128 accountId) external returns (bool canLiquidate) {
        // todo: consider moving it away from here into the account manager given that this is calculated by Account.sol now
    }
    /**
     * @inheritdoc ILiquidationEngine
     */

    function getAccountMarginRequirements(uint128 accountId)
        external
        view
        returns (uint256 initialMarginRequirementD18, uint256 liquidationMarginRequirementD18)
    {
        // todo: consider moving it away from here into the account manager given that this is calculated by Account.sol now
    }
    /**
     * @inheritdoc ILiquidationEngine
     */
    function isAccountIMSatisfied(uint128 accountID) external view returns (bool isIMSatisfied) {
        // todo: consider moving it away from here into the account manager given that this is calculated by Account.sol now
    }
}

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
    function isAccountLiquidatable(uint128 accountId) external returns (bool canLiquidate) {}
    /**
     * @inheritdoc ILiquidationEngine
     */

    function getAccountMarginRequirements(uint128 accountId)
        external
        view
        returns (uint256 initialMarginRequirementD18, uint256 liquidationMarginRequirementD18)
    {}
    /**
     * @inheritdoc ILiquidationEngine
     */
    function isAccountIMSatisfied(uint128 accountID) external view returns (bool isIMSatisfied) {}

    // todo: where should this function live? in the account or in the liquidation engine
    // how can the account talk to the product manager
    // function getAccountAnnualizedExposures(uint128 accountId) internal returns (Exposure[] memory exposures) {
    //     Account.exists(accountId);
    //     Account.Data storage account = Account.load(accountId);
    //     uint256 _activeProductIdsLength = account.activeProductIds.length;

    //     for (uint256 i = 0; i < _activeMarketIdsLength; i++) {
    //         // need to get the product by talking to the product manager
    //     }
    // }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../accounts/storage/Account.sol";
import "../utils/errors/ParameterError.sol";
import "../interfaces/ILiquidationEngine.sol";

/**
 * @title Module for liquidated accounts
 * @dev See ILiquidationEngine
 */

contract LiquidationModule is ILiquidationModule {
    function getAccountMarginRequirements(uint128 accountId) external view override {
        // load the account
        // get annualized filled and unfilled orders
        // we could cache the length of the array to avoid calculating it every time in this func

        // annualizedFilledAndUnfilledOrders = [];
        // worstCaseFilledOrders = [];

        // for ()
    }

    function getAccountAnnualizedExposures(uint128 accountId) internal returns (Exposure[] memory exposures) {
        Account.exists(accountId);
        Account.Data storage account = Account.load(accountId);
        uint256 _activeMarketIdsLength = account.activeMarketIds.length;

        for (uint256 i = 0; i < _activeMarketIdsLength; i++) {
            // need to get the product by talking to the product manager
        }
    }
}

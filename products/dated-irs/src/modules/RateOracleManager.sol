// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IRateOracleModule.sol";
import "../interfaces/IRateOracle.sol";
import "../storage/RateOracleReader.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

/**
 * @title Module for managing rate oracles connected to the Dated IRS Product
 * @dev See IRateOracleModule
 *  // todo: register a new rate oracle
 * // I'd call this RateOracleManagerModule to avoid confusion
 */
contract RateOracleManager is IRateOracleModule {
    using RateOracleReader for RateOracleReader.Data;

    /**
     * @inheritdoc IRateOracleModule
     */

    function getRateIndexCurrent(
        uint128 marketId,
        uint32 maturityTimestamp
    )
        external
        view
        override
        returns (UD60x18 rateIndexCurrent)
    {
        return RateOracleReader.load(marketId).getRateIndexCurrent(maturityTimestamp);
    }

    /**
     * @inheritdoc IRateOracleModule
     */
    function getRateIndexMaturity(
        uint128 marketId,
        uint32 maturityTimestamp
    )
        external
        view
        override
        returns (UD60x18 rateIndexMaturity)
    {
        return RateOracleReader.load(marketId).getRateIndexMaturity(maturityTimestamp);
    }

    // todo: do we want this function to return something?
    // todo: needs a feature flag to check for permission to register new variable rate oracles
    // todo: can we enable editing existing rate oracles?
    function registerVariableOracle(uint128 marketId, address oracleAddress) external override {
        if (_isVariableOracleRegistered(marketId)) {
            return;
        }

        if (!_validateVariableOracleAddress(oracleAddress)) {
            revert InvalidVariableOracleAddress(oracleAddress);
        }

        // register the variable rate oracle
        RateOracleReader.create(marketId, oracleAddress);
        emit RateOracleRegistered(marketId, oracleAddress);
    }

    function _isVariableOracleRegistered(uint128 marketId) internal returns (bool) {
        return RateOracleReader.load(marketId).oracleAddress != address(0);
    }

    // TODO: implement
    function _validateVariableOracleAddress(address oracleAddress) internal returns (bool isValid) {
        return IERC165(oracleAddress).supportsInterface(type(IRateOracle).interfaceId);
    }
}

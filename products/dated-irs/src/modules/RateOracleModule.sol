/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "../interfaces/IRateOracleModule.sol";
import "../interfaces/IRateOracle.sol";
import "../storage/RateOracleReader.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

/**
 * @title Module for managing rate oracles connected to the Dated IRS Product
 * @dev See IRateOracleModule
 */
contract RateOracleModule is IRateOracleModule {
    using RateOracleReader for RateOracleReader.Data;

    /**
     * @inheritdoc IRateOracleModule
     */

    function getRateIndexCurrent(
        uint128 marketId
    )
        external
        view
        override
        returns (UD60x18 rateIndexCurrent)
    {
        return RateOracleReader.load(marketId).getRateIndexCurrent();
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

    /**
    * @inheritdoc IRateOracleModule
     */
    function getVariableOracleAddress(uint128 marketId) external view override returns (address variableOracleAddress) {
        return RateOracleReader.load(marketId).oracleAddress;
    }

    /**
     * @inheritdoc IRateOracleModule
     */
    function setVariableOracle(uint128 marketId, address oracleAddress, uint256 maturityIndexCachingWindowInSeconds)
    external override {
        OwnableStorage.onlyOwner();

        validateAndConfigureOracleAddress(marketId, oracleAddress, maturityIndexCachingWindowInSeconds);
    }


    /**
     * @inheritdoc IRateOracleModule
     */
    function updateRateIndexAtMaturityCache(uint128 marketId, uint32 maturityTimestamp) external override {
        RateOracleReader.load(marketId).updateRateIndexAtMaturityCache(maturityTimestamp);
    }

    /**
     * @inheritdoc IRateOracleModule
     */
    function backfillRateIndexAtMaturityCache(uint128 marketId, uint32 maturityTimestamp,
        UD60x18 rateIndexAtMaturity) external override {

        OwnableStorage.onlyOwner();

        RateOracleReader.load(marketId).backfillRateIndexAtMaturityCache(maturityTimestamp, rateIndexAtMaturity);

    }

    /**
     * @dev Validates the address interface and creates or configures a rate oracle
     */
    function validateAndConfigureOracleAddress(uint128 marketId, address oracleAddress,
        uint256 maturityIndexCachingWindowInSeconds) internal {
        if (!_validateVariableOracleAddress(oracleAddress)) {
            revert InvalidVariableOracleAddress(oracleAddress);
        }

        // configure the variable rate oracle
        RateOracleReader.set(marketId, oracleAddress, maturityIndexCachingWindowInSeconds);

        emit RateOracleConfigured(marketId, oracleAddress, maturityIndexCachingWindowInSeconds, block.timestamp);
    }

    function _validateVariableOracleAddress(address oracleAddress) internal view returns (bool isValid) {
        return IERC165(oracleAddress).supportsInterface(type(IRateOracle).interfaceId);
    }
}

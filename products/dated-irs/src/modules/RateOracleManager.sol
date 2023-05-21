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

    /**
     * @inheritdoc IRateOracleModule
     */
    function registerVariableOracle(uint128 marketId, address oracleAddress) external override {
        OwnableStorage.onlyOwner();

        if (_isVariableOracleRegistered(marketId)) {
            revert AlreadyRegisteredVariableOracle(oracleAddress);
        }

        validateAndConfigureOracleAddress(marketId, oracleAddress);
        emit RateOracleRegistered(marketId, oracleAddress);
    }

    /**
     * @inheritdoc IRateOracleModule
     */
    function configureVariableOracle(uint128 marketId, address oracleAddress) external override {
        OwnableStorage.onlyOwner();

        if (!_isVariableOracleRegistered(marketId)) {
            revert UnknownVariableOracle(oracleAddress);
        }

        validateAndConfigureOracleAddress(marketId, oracleAddress);
        emit RateOracleConfigured(marketId, oracleAddress);
    }

    /**
     * @dev Validates the address interface and creates or configures a rate oracle
     */
    function validateAndConfigureOracleAddress(uint128 marketId, address oracleAddress) internal {
        if (!_validateVariableOracleAddress(oracleAddress)) {
            revert InvalidVariableOracleAddress(oracleAddress);
        }

        // configure the variable rate oracle
        RateOracleReader.set(marketId, oracleAddress);
    }

    function _isVariableOracleRegistered(uint128 marketId) internal returns (bool) {
        return RateOracleReader.load(marketId).oracleAddress != address(0);
    }

    function _validateVariableOracleAddress(address oracleAddress) internal returns (bool isValid) {
        return IERC165(oracleAddress).supportsInterface(type(IRateOracle).interfaceId);
    }
}

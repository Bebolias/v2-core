// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IOracleManager.sol";

/**
 * @title Module for managing oracles connected to the protocol
 * @dev See IOracleManager
 */
contract OracleManager is IOracleManager {
    /**
     * @inheritdoc IOracleManager
     */
    function snapshotRateIndex(uint128 marketId, uint256 maturityTimestamp) external view returns (int256 rateIndex) {}
}

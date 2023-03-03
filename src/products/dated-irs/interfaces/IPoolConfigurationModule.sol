//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../storage/PoolConfiguration.sol";

/**
 * @title Module for configuring the pool attached to the dated irs product
 * @notice Allows the owner to configure the pool address that the dated irs product references
 */

interface IPoolConfigurationModule {
    /**
     * @notice Emitted when a pool configuration is created or updated
     * @param config The object with the newly configured details.
     */
    event PoolConfigured(PoolConfiguration.Data config);

    /**
     * @notice Creates or updates the pool configuration
     * @param config The PoolConfiguration object describing the new configuration.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner of the dated irs product.
     *
     * Emits a {PoolConfigured} event.
     *
     */
    function configurePool(PoolConfiguration.Data memory config) external;

    /**
     * @notice Returns the pool configuration
     * @return config The configuration object describing the pool
     */
    function getPoolConfiguration() external view returns (PoolConfiguration.Data memory config);
}

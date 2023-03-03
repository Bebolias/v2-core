// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IPoolConfigurationModule.sol";
import "../storage/PoolConfiguration.sol";
import "../../../utils/storage/OwnableStorage.sol";

/**
 * @title Module for configuring the pool linked to the dated irs product
 * @dev See IPoolConfigurationModule.
 */
contract PoolConfigurationModule is IPoolConfigurationModule {
    using PoolConfiguration for PoolConfiguration.Data;

    /**
     * @inheritdoc IPoolConfigurationModule
     */
    function configurePool(PoolConfiguration.Data memory config) external {
        OwnableStorage.onlyOwner();

        PoolConfiguration.set(config);

        emit PoolConfigured(config);
    }

    /**
     * @inheritdoc IPoolConfigurationModule
     */
    // solc-ignore-next-line func-mutability
    function getPoolConfiguration() external view returns (PoolConfiguration.Data memory config) {
        return PoolConfiguration.load();
    }
}

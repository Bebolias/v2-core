//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IConfigurationModule.sol";
import "../storage/Config.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

/**
 * @title Module for configuring the periphery
 * @dev See IConfigurationModule.
 */
contract ConfigurationModule is IConfigurationModule {
    using Config for Config.Data;

    /**
     * @inheritdoc ICollateralConfigurationModule
     */
    function configure(CollateralConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();

        Config.set(config);

        emit PeripheryConfigured(config);
    }
}

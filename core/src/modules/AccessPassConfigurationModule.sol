/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "../interfaces/IAccessPassConfigurationModule.sol";
import "../storage/AccessPassConfiguration.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

/**
 * @title Module for access pass nft configuration
 * @dev See IAccessPassConfigurationModule
*/
contract AccessPassConfigurationModule is IAccessPassConfigurationModule {

    /**
     * @inheritdoc IAccessPassConfigurationModule
     */
    function configureAccessPass(AccessPassConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();
        AccessPassConfiguration.set(config);
        emit AccessPassConfigured(config, block.timestamp);
    }


    /**
     * @inheritdoc IAccessPassConfigurationModule
     */
    function getAccessPassConfiguration() external pure returns (AccessPassConfiguration.Data memory config) {
        return AccessPassConfiguration.load();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IMarketConfigurationModule.sol";
import "../storage/MarketConfiguration.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

/**
 * @title Module for configuring a market
 * @dev See IMarketConfigurationModule.
 */
contract MarketConfigurationModule is IMarketConfigurationModule {
    using MarketConfiguration for MarketConfiguration.Data;

    /**
     * @inheritdoc IMarketConfigurationModule
     */
    function configureMarket(MarketConfiguration.Data memory config) external {
        OwnableStorage.onlyOwner();

        MarketConfiguration.set(config);

        emit MarketConfigured(config);
    }

    /**
     * @inheritdoc IMarketConfigurationModule
     */
    // solc-ignore-next-line func-mutability
    function getMarketConfiguration(uint128 irsMarketId) external view returns (MarketConfiguration.Data memory config) {
        return MarketConfiguration.load(irsMarketId);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IRiskConfigurationModule.sol";
import "../storage/MarketRiskConfiguration.sol";
import "../storage/ProtocolRiskConfiguration.sol";
import "../utils/contracts//storage/OwnableStorage.sol";

/**
 * @title Module for configuring protocol-wide and product+market level risk parameters
 * @dev See IRiskConfigurationModule
 */
contract RiskConfigurationModule is IRiskConfigurationModule {
    /**
     * @inheritdoc IRiskConfigurationModule
     */
    function configureMarketRisk(MarketRiskConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();
        MarketRiskConfiguration.set(config);
        emit MarketRiskConfigured(config);
    }

    /**
     * @inheritdoc IRiskConfigurationModule
     */
    function configureProtocolRisk(ProtocolRiskConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();
        ProtocolRiskConfiguration.set(config);
        emit ProtocolRiskConfigured(config);
    }
    /**
     * @inheritdoc IRiskConfigurationModule
     */
    // solc-ignore-next-line func-mutability

    function getMarketRiskConfiguration(
        uint128 productId,
        uint128 marketId
    )
        external
        view
        override
        returns (MarketRiskConfiguration.Data memory config)
    {
        return MarketRiskConfiguration.load(productId, marketId);
    }

    /**
     * @inheritdoc IRiskConfigurationModule
     */
    // solc-ignore-next-line func-mutability
    function getProtocolRiskConfiguration() external view returns (ProtocolRiskConfiguration.Data memory config) {
        return ProtocolRiskConfiguration.load();
    }
}

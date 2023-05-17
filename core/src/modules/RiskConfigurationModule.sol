pragma solidity >=0.8.19;

import "../interfaces/IRiskConfigurationModule.sol";
import "../storage/MarketRiskConfiguration.sol";
import "../storage/ProtocolRiskConfiguration.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

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
        emit MarketRiskConfigured(config, block.timestamp);
    }

    /**
     * @inheritdoc IRiskConfigurationModule
     */
    function configureProtocolRisk(ProtocolRiskConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();
        ProtocolRiskConfiguration.set(config);
        emit ProtocolRiskConfigured(config, block.timestamp);
    }

    /**
     * @inheritdoc IRiskConfigurationModule
     */
    function getMarketRiskConfiguration(uint128 productId, uint128 marketId)
        external
        pure
        override
        returns (MarketRiskConfiguration.Data memory config)
    {
        return MarketRiskConfiguration.load(productId, marketId);
    }

    /**
     * @inheritdoc IRiskConfigurationModule
     */
    function getProtocolRiskConfiguration() external pure returns (ProtocolRiskConfiguration.Data memory config) {
        return ProtocolRiskConfiguration.load();
    }
}

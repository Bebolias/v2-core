//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";
import "../interfaces/IFeeConfigurationModule.sol";
import "../storage/MarketFeeConfiguration.sol";

contract FeeConfigurationModule is IFeeConfigurationModule {
    /**
     * @inheritdoc IFeeConfigurationModule
     */
    function configureMarketFee(MarketFeeConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();
        MarketFeeConfiguration.set(config);
        emit MarketFeeConfigured(config, block.timestamp);
    }

    /**
     * @inheritdoc IFeeConfigurationModule
     */
    function getMarketFeeConfiguration(uint128 productId, uint128 marketId)
        external
        pure
        override
        returns (MarketFeeConfiguration.Data memory config)
    {
        return MarketFeeConfiguration.load(productId, marketId);
    }
}

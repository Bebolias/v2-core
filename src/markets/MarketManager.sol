//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IMarket.sol";
import "./storage/Market.sol";
import "./storage/MarketCreator.sol";
import "../utils/storage/AssociatedSystem.sol";

/**
 * @title System-wide entry point for the management of markets connected to the protocol.
 * @dev See IMarketManager
 */
contract MarketManager is IMarketManager {
    using Market for Market.Data;
    using AssociatedSystem for AssociatedSystem.Data;

    /**
     * @inheritdoc IMarketManagerModule
     */
    function registerMarket(address market) external override returns (uint128 marketId) {
        if (!ERC165Helper.safeSupportsInterface(market, type(IMarket).interfaceId)) {
            revert IncorrectMarketInterface(market);
        }

        marketId = MarketCreator.create(market).id;

        emit MarketRegistered(market, marketId, msg.sender);

        return marketId;
    }
}

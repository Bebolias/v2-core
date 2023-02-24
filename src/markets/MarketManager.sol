//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IMarket.sol";
import "../interfaces/IMarketManager.sol";
import "./storage/Market.sol";
import "./storage/MarketCreator.sol";
import "../utils/storage/AssociatedSystem.sol";
import "../utils/helpers/ERC165Helper.sol";

/**
 * @title Protocol-wide entry point for the management of markets connected to the protocol.
 * @dev See IMarketManager
 */
contract MarketManager is IMarketManager {
    using Market for Market.Data;
    using AssociatedSystem for AssociatedSystem.Data;

    /**
     * @inheritdoc IMarketManager
     */
    function getAccountUnrealizedPnLInQuote(uint128 marketId, uint128 accountId)
        external
        view
        override
        returns (int256 accountUnrealizedPnLInQuote)
    {
        accountUnrealizedPnLInQuote = Market.load(marketId).getAccountUnrealizedPnLInQuote(accountId);
    }

    /**
     * @inheritdoc IMarketManager
     */
    function getAccountAnnualizedFilledUnfilledNotionalsInQuote(uint128 marketId, uint128 accountId)
        external
        view
        override
        returns (int256 filledNotional, uint256 unfilledLongNotional, uint256 unfilledShortNotional)
    {
        (filledNotional, unfilledLongNotional, unfilledShortNotional) =
            Market.load(marketId).getAccountAnnualizedFilledUnfilledNotionalsInQuote(accountId);
    }

    /**
     * @inheritdoc IMarketManager
     */
    function registerMarket(address market) external override returns (uint128 marketId) {
        // todo: ensure acces to feature flag check

        if (!ERC165Helper.safeSupportsInterface(market, type(IMarket).interfaceId)) {
            revert IncorrectMarketInterface(market);
        }

        marketId = MarketCreator.create(market, msg.sender).id;

        emit MarketRegistered(market, marketId, msg.sender);

        return marketId;
    }

    /**
     * @inheritdoc IMarketManager
     */

    function closeAccount(uint128 marketId, uint128 accountId) external override {
        // todo: consider returning data that might be useful in the future
        Market.load(marketId).closeAccount(accountId);
    }
}

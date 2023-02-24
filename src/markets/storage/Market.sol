// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/errors/AccessError.sol";
import "../../interfaces/IMarket.sol";

/**
 * @title Connects external contracts that implement the `IMarket` interface to the protocol.
 *
 */
library Market {
    /**
     * @dev Thrown when a specified market is not found.
     */
    error MarketNotFound(uint128 marketId);

    struct Data {
        /**
         * @dev Numeric identifier for the market. Must be unique.
         * @dev There cannot be a market with id zero (See MarketCreator.create()). Id zero is used as a null market reference.
         */
        uint128 id;
        /**
         * @dev Address for the external contract that implements the `IMarket` interface, which this Market objects connects to.
         *
         * Note: This object is how the system tracks the market. The actual market is external to the system, i.e. its own contract.
         */
        address productAddress;
        /**
         * @dev Address of the quote token in which this market settles
         */
        address quoteAddress;
        /**
         * @dev Text identifier for the market.
         *
         * Not required to be unique.
         */
        string name;
        /**
         * @dev Creator of the market, which has configuration access rights for the market.
         *
         * See onlyMarketOwner.
         */
        address owner;
    }

    /**
     * @dev Returns the market stored at the specified market id.
     */
    function load(uint128 id) internal pure returns (Data storage market) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Market", id));
        assembly {
            market.slot := s
        }
    }

    /**
     * @dev Reverts if the caller is not the owner of the specified market
     */
    function onlyMarketOwner(uint128 marketId, address caller) internal view {
        if (Market.load(marketId).owner != caller) {
            revert AccessError.Unauthorized(caller);
        }
    }

    function getAccountUnrealizedPnLInQuote(Data storage self, uint128 accountId)
        internal
        view
        returns (int256 accountUnrealizedPnLInQuote)
    {
        // todo: rename IMarket to IProduct?
        // getAccountUnrealizedPnLInQuote inside of the product aggregates the pnl for all maturities and pools
        // each market has a product address
        return IMarket(self.productAddress).getAccountUnrealizedPnLInQuote(accountId);
    }
}

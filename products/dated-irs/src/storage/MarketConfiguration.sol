//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

// do we need this?
/**
 * @title Tracks configurations for dated irs markets
 */
library MarketConfiguration {
    error MarketAlreadyExists(uint128 marketId);

    struct Data {
        // todo: new market ids should be created here
        /**
         * @dev Id fo a given interest rate swap market
         */
        uint128 marketId;
        /**
         * @dev Address of the quote token.
         * @dev IRS contracts settle in the quote token
         * i.e. settlement cashflows and unrealized pnls are in quote token terms
         */
        address quoteToken;
    }

    /**
     * @dev Loads the MarketConfiguration object for the given dated irs market id
     * @param irsMarketId Id of the IRS market that we want to load the configurations for
     * @return datedIRSMarketConfig The CollateralConfiguration object.
     */
    function load(uint128 irsMarketId) internal pure returns (Data storage datedIRSMarketConfig) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.MarketConfiguration", irsMarketId));
        assembly {
            datedIRSMarketConfig.slot := s
        }
    }

    /**
     * @dev Configures a dated interest rate swap market
     * @param config The MarketConfiguration object with all the settings for the irs market being configured.
     */
    function set(Data memory config) internal {
        require(config.quoteToken != address(0), "Invalid Market");

        Data storage storedConfig = load(config.marketId);

        if (storedConfig.quoteToken != address(0)) {
            revert MarketAlreadyExists(config.marketId);
        }

        storedConfig.marketId = config.marketId;
        storedConfig.quoteToken = config.quoteToken;
    }
}

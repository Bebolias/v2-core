// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/helpers/SetUtil.sol";

/**
 * @title Object for tracking dated positions, e.g. locked dated interest rate swap contracts
 */
library DatedPortfolio {
    struct Data {
        /**
         * @dev Numeric identifier for the account that owns the portfolio.
         * @dev Since a given account can only own a single portfolio in a given dated product
         * the id of the portfolio is the same as the id of the account
         * @dev There cannot be an account and hence dated portfolio with id zero
         */
        uint128 id;
        /**
         * @dev marketId (e.g. aUSDC lend) --> maturityTimestamp (e.g. 31st Dec 2023) --> DatedPosition object with filled balances
         */
        mapping(uint128 => mapping(uint256 => DatedPosition.Data)) positions;
        /**
         * @dev Ids of all the markets in which the account has active positions
         * todo: needs logic to mark active markets
         */
        SetUtil.UintSet activeMarkets;
        /**
         * @dev marketId (e.g. aUSDC lend) -> activeMaturities (e.g. 31st Dec 2023)
         */
        mapping(uint128 => SetUtil.UintSet) activeMaturitiesPerMarket;
    }
}

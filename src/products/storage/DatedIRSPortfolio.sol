// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/helpers/SetUtil.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library DatedIRSPortfolio {
    struct Data {
        /**
         * @dev Numeric identifier for the account that owns the portfolio.
         * @dev Since a given account can only own a single portfolio in a given dated product
         * the id of the portfolio is the same as the id of the account
         * @dev There cannot be an account and hence dated portfolio with id zero
         */
        uint128 accountId;
        /**
         * @dev marketId (e.g. aUSDC lend) --> maturityTimestamp (e.g. 31st Dec 2023) --> DatedIRSPosition object with filled balances
         */
        mapping(uint128 => mapping(uint256 => DatedIRSPosition.Data)) positions;
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

    /**
     * @dev Returns the portfolio stored at the specified portfolio  id.
     */
    function load(uint128 id) internal pure returns (Data storage portfolio) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.DatedIRSPortfolio", id));
        assembly {
            account.slot := s
        }
    }

    /**
     * @dev Creates a portfolio for a given id, the id of the portfolio and the account that owns it are the same
     */
    function create(uint128 id) internal returns (Data storage portfolio) {
        portfolio = load(id);
        // note, the portfolio id is the same as the account id that owns this portfolio
        portfolio.accountId = id;
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function updatePosition(
        Data storage self,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseDelta,
        int256 quoteDelta
    ) internal {
        DatedIRSPosition.Data storage position = self.positions[marketId][maturityTimestamp];
        position.update(baseDelta, quoteDelta);
    }
}

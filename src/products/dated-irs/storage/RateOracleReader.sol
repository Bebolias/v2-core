// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IRateOracle.sol";
import "src/utils/helpers/Time.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

library RateOracleReader {
    /**
     * @dev Thrown if the index-at-maturity is requested before maturity.
     */
    error MaturityNotReached();

    struct PreMaturityData {
        uint40 lastKnownTimestamp;
        UD60x18 lastKnownIndex; // TODO - truncate indices to UD40x18 (nned to define this and faciliate checked casting) to save a
            // storage slot here and elsewhere
    }

    struct Data {
        uint128 marketId;
        address oracleAddress;
        mapping(uint256 => PreMaturityData) rateIndexPreMaturity;
        mapping(uint256 => UD60x18) rateIndexAtMaturity;
    }

    function load(uint128 marketId) internal pure returns (Data storage oracle) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.RateOracleReader", marketId));
        assembly {
            oracle.slot := s
        }
    }

    function create(uint128 marketId, address oracleAddress) internal returns (Data storage oracle) {
        oracle = load(marketId);
        oracle.marketId = marketId;
        oracle.oracleAddress = oracleAddress;
    }

    function getRateIndexCurrent(Data storage self, uint256 maturityTimestamp) internal view returns (UD60x18 rateIndexCurrent) {
        if (block.timestamp >= maturityTimestamp) {
            // maturity timestamp has passed
            UD60x18 rateIndexMaturity = self.rateIndexAtMaturity[maturityTimestamp];

            if (rateIndexMaturity.unwrap() == 0) {
                // cache not yet populated - populate it now
                UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();

                // todo: write on registration
                // todo: write for each taker order with some threshold closer towards maturity
                // todo: bring views back and simplify the logic below

                // TODO: if we can guarantee that a cache value exists (maybe writing to cache on oracle registration?) then code
                // here and below can simplify
                PreMaturityData memory cache = self.rateIndexPreMaturity[maturityTimestamp];

                // if (cache.lastKnownTimestamp == 0) {
                //     self.rateIndexAtMaturity[maturityTimestamp] = currentIndex;
                // } else {
                //     // We know a rate before settlment and now at/after settlement => interpolate between them
                // }

                rateIndexMaturity = IRateOracle(self.oracleAddress).interpolateIndexValue({
                    beforeIndex: cache.lastKnownIndex,
                    beforeTimestamp: cache.lastKnownTimestamp,
                    atOrAfterIndex: currentIndex,
                    atOrAfterTimestamp: block.timestamp,
                    queryTimestamp: maturityTimestamp
                });
                // self.rateIndexAtMaturity[maturityTimestamp] = rateIndexMaturity;
            }
            return rateIndexMaturity;
        } else {
            // timestamp has not yet passed. We will update the cache unless proven otherwise
            UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();

            bool updateCache = true;
            PreMaturityData storage cache = self.rateIndexPreMaturity[maturityTimestamp];
            if (cache.lastKnownTimestamp > 0) {
                // We have saved a pre-maturity value already; check whether we need to update it
                uint256 timeTillMaturity = maturityTimestamp - block.timestamp;
                uint256 timeSinceLastWrite = block.timestamp - cache.lastKnownTimestamp;
                if (timeSinceLastWrite < timeTillMaturity) {
                    // We only update the cache if we are at least halfway to maturity since the last cache update
                    // This heuristic should give us a timestamp very close to the maturity timestamp, but should save unnecessary
                    // writes early in the life of a given IRS
                    updateCache = false;
                }
            }

            // if (updateCache) {
            //     cache.lastKnownTimestamp = Time.blockTimestampTruncated();
            //     cache.lastKnownIndex = currentIndex;
            // }

            return currentIndex;
        }
    }

    function getRateIndexMaturity(Data storage self, uint256 maturityTimestamp) internal returns (UD60x18 rateIndexMaturity) {
        if (block.timestamp < maturityTimestamp) {
            revert MaturityNotReached();
        }

        return getRateIndexCurrent(self, maturityTimestamp);
    }
}

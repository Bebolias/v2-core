// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../interfaces/IRateOracle.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

library RateOracleReader {
    using { unwrap } for UD60x18;
    /**
     * @dev Thrown if the index-at-maturity is requested before maturity.
     */

    error MaturityNotReached();
    error MissingRateIndexAtMaturity();

    struct PreMaturityData {
        uint32 lastKnownTimestamp;
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

    function set(uint128 marketId, address oracleAddress) internal returns (Data storage oracle) {
        oracle = load(marketId);
        oracle.marketId = marketId;
        oracle.oracleAddress = oracleAddress;
    }

    function updateCache(Data storage self, uint32 maturityTimestamp) internal {
        if (Time.blockTimestampTruncated() >= maturityTimestamp) {
            // maturity timestamp has passed
            UD60x18 rateIndexMaturity = self.rateIndexAtMaturity[maturityTimestamp];
            if (rateIndexMaturity.unwrap() == 0) {
                // cache not yet populated - populate it now
                UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();
                PreMaturityData memory cache = self.rateIndexPreMaturity[maturityTimestamp];

                if (cache.lastKnownTimestamp == 0) {
                    self.rateIndexAtMaturity[maturityTimestamp] = currentIndex;
                } else {
                    // We know a rate before settlment and now at/after settlement => interpolate between them
                    rateIndexMaturity = IRateOracle(self.oracleAddress).interpolateIndexValue({
                        beforeIndex: cache.lastKnownIndex,
                        beforeTimestamp: cache.lastKnownTimestamp,
                        atOrAfterIndex: currentIndex,
                        atOrAfterTimestamp: Time.blockTimestampTruncated(),
                        queryTimestamp: maturityTimestamp
                    });
                    self.rateIndexAtMaturity[maturityTimestamp] = rateIndexMaturity;
                }
            }
        } else {
            // timestamp has not yet passed

            UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();
            bool shouldUpdateCache = true;
            PreMaturityData storage cache = self.rateIndexPreMaturity[maturityTimestamp];
            if (cache.lastKnownTimestamp > 0) {
                // We have saved a pre-maturity value already; check whether we need to update it
                uint256 timeTillMaturity = maturityTimestamp - Time.blockTimestampTruncated();
                uint256 timeSinceLastWrite = Time.blockTimestampTruncated() - cache.lastKnownTimestamp;
                if (timeSinceLastWrite < timeTillMaturity) {
                    // We only update the cache if we are at least halfway to maturity since the last cache update
                    // This heuristic should give us a timestamp very close to the maturity timestamp, but should save unnecessary
                    // writes early in the life of a given IRS
                    shouldUpdateCache = false;
                }
            }

            if (shouldUpdateCache) {
                cache.lastKnownTimestamp = Time.blockTimestampTruncated();
                cache.lastKnownIndex = currentIndex;
            }
        }
    }

    function getRateIndexCurrent(Data storage self, uint32 maturityTimestamp) internal view returns (UD60x18 rateIndexCurrent) {
        if (Time.blockTimestampTruncated() >= maturityTimestamp) {
            // maturity timestamp has passed
            UD60x18 rateIndexMaturity = self.rateIndexAtMaturity[maturityTimestamp];

            if (rateIndexMaturity.unwrap() == 0) {
                UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();

                PreMaturityData memory cache = self.rateIndexPreMaturity[maturityTimestamp];

                if (cache.lastKnownTimestamp == 0) {
                    revert MissingRateIndexAtMaturity();
                }
                rateIndexMaturity = IRateOracle(self.oracleAddress).interpolateIndexValue({
                    beforeIndex: cache.lastKnownIndex,
                    beforeTimestamp: cache.lastKnownTimestamp,
                    atOrAfterIndex: currentIndex,
                    atOrAfterTimestamp: Time.blockTimestampTruncated(),
                    queryTimestamp: maturityTimestamp
                });
            }
            return rateIndexMaturity;
        } else {
            UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();
            return currentIndex;
        }
    }

    function getRateIndexMaturity(Data storage self, uint32 maturityTimestamp) internal view returns (UD60x18 rateIndexMaturity) {
        if (Time.blockTimestampTruncated() <= maturityTimestamp) {
            revert MaturityNotReached();
        }

        return getRateIndexCurrent(self, maturityTimestamp);
    }
}

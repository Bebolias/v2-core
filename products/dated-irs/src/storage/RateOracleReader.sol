/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
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


    /**
     * @dev Thrown if more than maturityIndexCachingWindowInSeconds has elapsed since the maturity timestamp
     */

    error MaturityIndexCachingWindowElapsed();


    /**
     * @dev Thrown if the maturity index caching window is ongoing in context of maturity index backfill
     */
    error MaturityIndexCachingWindowOngoing();


    /**
     * @notice Emitted when new maturity rate is cached
     * @param marketId The id of the market.
     * @param oracleAddress The address of the oracle.
     * @param timestamp The timestamp of the rate.
     * @param rate The value of the rate.
     * @param blockTimestamp The current block timestamp.
     */
    event RateOracleCacheUpdated(
        uint128 indexed marketId, address oracleAddress, uint32 timestamp, uint256 rate, uint256 blockTimestamp
    );

    struct Data {
        uint128 marketId;
        address oracleAddress;
        uint256 maturityIndexCachingWindowInSeconds;
        mapping(uint256 => UD60x18) rateIndexAtMaturity;
    }

    function load(uint128 marketId) internal pure returns (Data storage oracle) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.RateOracleReader", marketId));
        assembly {
            oracle.slot := s
        }
    }

    function set(uint128 marketId, address oracleAddress, uint256 maturityIndexCachingWindowInSeconds)
        internal returns (Data storage oracle) {
        oracle = load(marketId);
        oracle.marketId = marketId;
        oracle.oracleAddress = oracleAddress;
        oracle.maturityIndexCachingWindowInSeconds = maturityIndexCachingWindowInSeconds;
    }

    function backfillRateIndexAtMaturityCache(Data storage self, uint32 maturityTimestamp, UD60x18 rateIndexAtMaturity) internal {

        if (Time.blockTimestampTruncated() < maturityTimestamp) {
            revert MaturityNotReached();
        }

        if (Time.blockTimestampTruncated() < maturityTimestamp + self.maturityIndexCachingWindowInSeconds) {
            revert MaturityIndexCachingWindowOngoing();
        }

        self.rateIndexAtMaturity[maturityTimestamp] = rateIndexAtMaturity;

        emit RateOracleCacheUpdated(
            self.marketId,
            self.oracleAddress,
            maturityTimestamp,
            self.rateIndexAtMaturity[maturityTimestamp].unwrap(),
            block.timestamp
        );
    }

    function updateRateIndexAtMaturityCache(Data storage self, uint32 maturityTimestamp) internal {

        if (self.rateIndexAtMaturity[maturityTimestamp].unwrap() == 0) {

            if (Time.blockTimestampTruncated() < maturityTimestamp) {
                revert MaturityNotReached();
            }

            if (Time.blockTimestampTruncated() > maturityTimestamp + self.maturityIndexCachingWindowInSeconds) {
                revert MaturityIndexCachingWindowElapsed();
            }

            self.rateIndexAtMaturity[maturityTimestamp] = IRateOracle(self.oracleAddress).getCurrentIndex();

            emit RateOracleCacheUpdated(
                self.marketId,
                self.oracleAddress,
                maturityTimestamp,
                self.rateIndexAtMaturity[maturityTimestamp].unwrap(),
                block.timestamp
            );
        }

    }


    function getRateIndexCurrent(Data storage self, uint32 maturityTimestamp) internal view returns (UD60x18 rateIndexCurrent) {
        /*
            Note, need thoughts here for protocols where current index does not correspond to the current timestamp (block.timestamp)
            ref. Lido and Rocket
        */
        return IRateOracle(self.oracleAddress).getCurrentIndex();
    }

    function getRateIndexMaturity(Data storage self, uint32 maturityTimestamp) internal view returns (UD60x18 rateIndexMaturity) {

        /*
            Note, for some period of time (until cache is captured) post maturity, the rate index cached for the maturity
            will be zero
        */

        if (Time.blockTimestampTruncated() <= maturityTimestamp) {
            revert MaturityNotReached();
        }

        return self.rateIndexAtMaturity[maturityTimestamp];
    }
}

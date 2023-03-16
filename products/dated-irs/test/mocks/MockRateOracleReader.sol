// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../src/interfaces/IRateOracle.sol";
import "../../src/utils/contracts/src/helpers/Time.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

contract MockRateOracleReader {

    using RateOracleReader for RateOracleReader.Data;

    function setIndexCache(uint40 lastKnownTimestamp, UD60x18 lastKnownIndex, uint256 maturityTimestamp) public {
        self.rateIndexPreMaturity[maturityTimestamp].lastKnownTimestamp = lastKnownTimestamp;
        self.rateIndexPreMaturity[maturityTimestamp].lastKnownIndex = lastKnownIndex;
    }

    function setOracleIndex(uint256 index, address underlyingProtocolOracle) public {
        MockRateOracle(self.oracleAddress).setLastUpdatedIndex(index);
    }
}

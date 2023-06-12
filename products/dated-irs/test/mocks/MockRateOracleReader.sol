/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "../../src/interfaces/IRateOracle.sol";
import "../../src/storage/RateOracleReader.sol";
import "./MockRateOracle.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

contract MockRateOracleReader {
    using RateOracleReader for RateOracleReader.Data;

    address oracleAddress;

    constructor(address _oracleAddress) {
        oracleAddress = _oracleAddress;
    }

    // function setIndexCache(RateOracleReader.Data memory self, uint32 lastKnownTimestamp, UD60x18 lastKnownIndex, uint256
    // maturityTimestamp) public {
    //     self.rateIndexPreMaturity[maturityTimestamp].lastKnownTimestamp = lastKnownTimestamp;
    //     self.rateIndexPreMaturity[maturityTimestamp].lastKnownIndex = lastKnownIndex;
    // }

    function setOracleIndex(uint256 index, address underlyingProtocolOracle) public {
        MockRateOracle(oracleAddress).setLastUpdatedIndex(index);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IVariableRateOracle.sol";

library VariableRateOracle {
    struct Data {
        uint128 marketId;
        address oracleAddress;
        mapping(uint256 => uint256) rateIndexPerMaturity;
    }

    function load(uint128 marketId) internal pure returns (Data storage oracle) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.VariableRateOracle", marketId));
        assembly {
            oracle.slot := s
        }
    }

    function create(uint128 marketId, address oracleAddress) internal returns (Data storage oracle) {
        oracle = load(marketId);
        oracle.marketId = marketId;
        oracle.oracleAddress = oracleAddress;
    }

    function getRateIndexCurrent(Data storage self) internal view returns (uint256 rateIndexCurrent) {
        return IVariableRateOracle(self.oracleAddress).getRateIndexCurrent();
    }

    function getRateIndexMaturity(Data storage self, uint256 maturityTimestamp)
        internal
        returns (uint256 rateIndexMaturity)
    {
        // worth having a view and non-view versions of this function?

        if (block.timestamp < maturityTimestamp) {
            // todo: revert with a descriptive custom error
        }

        rateIndexMaturity = self.rateIndexPerMaturity[maturityTimestamp];

        if (rateIndexMaturity != 0) {
            // cache is populated
            // would there every be a scenario where the maturity rate index is 0?
            return rateIndexMaturity;
        }

        rateIndexMaturity = getRateIndexCurrent(self);
        self.rateIndexPerMaturity[maturityTimestamp] = rateIndexMaturity;
    }
}

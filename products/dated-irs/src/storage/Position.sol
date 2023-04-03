// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Object for tracking a dated irs position
 * todo: annualization logic might fit nicely in here + any other irs position specific helpers
 */
library Position {
    struct Data {
        int256 baseBalance;
        int256 quoteBalance;
    }

    function update(Data storage self, int256 baseDelta, int256 quoteDelta) internal {
        self.baseBalance += baseDelta;
        self.quoteBalance += quoteDelta;
    }

    function settle(Data storage self) internal {
        // todo: for now assuming no pools, but need to include pools asap)
        self.baseBalance = 0;
        self.quoteBalance = 0;
    }
}

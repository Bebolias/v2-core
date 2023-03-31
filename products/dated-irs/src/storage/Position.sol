// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { SD59x18, ZERO } from "@prb/math/SD59x18.sol";

/**
 * @title Object for tracking a dated irs position
 * todo: annualization logic might fit nicely in here + any other irs position specific helpers
 */
library Position {
    struct Data {
        SD59x18 baseBalance;
        SD59x18 quoteBalance;
    }

    function update(Data storage self, SD59x18 baseDelta, SD59x18 quoteDelta) internal {
        self.baseBalance = self.baseBalance.add(baseDelta);
        self.quoteBalance = self.baseBalance.add(quoteDelta);
    }

    function settle(Data storage self) internal {
        // todo: for now assuming no pools, but need to include pools asap)
        self.baseBalance = ZERO;
        self.quoteBalance = ZERO;
    }
}

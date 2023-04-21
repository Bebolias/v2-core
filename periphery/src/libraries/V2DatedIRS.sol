// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/products-dated-irs/src/interfaces/IProductIRSModule.sol";
import "../storage/Config.sol";

/**
 * @title Performs swaps and settements on top of the v2 dated irs instrument
 */
library V2DatedIRS {
    // todo: add price limit in here once implemented in the dated irs instrument
    function swap(uint128 accountId, uint128 marketId, uint32 maturityTimestamp, int256 baseAmount)
        internal
        returns (int256 executedBaseAmount, int256 executedQuoteAmount)
    {
        (executedBaseAmount, executedQuoteAmount) = IProductIRSModule(Config.load().VOLTZ_V2_DATED_IRS_PROXY)
            .initiateTakerOrder(accountId, marketId, maturityTimestamp, baseAmount);
    }

    function settle(uint128 accountId, uint128 marketId, uint32 maturityTimestamp) internal {
        IProductIRSModule(Config.load().VOLTZ_V2_DATED_IRS_PROXY).settle(accountId, marketID, maturityTimestamp);
    }
}

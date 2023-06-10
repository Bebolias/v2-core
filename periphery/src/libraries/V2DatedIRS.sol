// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/products-dated-irs/src/interfaces/IProductIRSModule.sol";
import "../storage/Config.sol";

/**
 * @title Performs swaps and settements on top of the v2 dated irs instrument
 */
library V2DatedIRS {
    // todo: add price limit in here once implemented in the dated irs instrument
    function swap(uint128 accountId, uint128 marketId, uint32 maturityTimestamp, int256 baseAmount, uint160 priceLimit)
        internal
        returns (int256 executedBaseAmount, int256 executedQuoteAmount, uint256 fee, uint256 im)
    {
        (executedBaseAmount, executedQuoteAmount, fee, im) = IProductIRSModule(Config.load().VOLTZ_V2_DATED_IRS_PROXY)
            .initiateTakerOrder(accountId, marketId, maturityTimestamp, baseAmount, priceLimit);
    }

    function settle(uint128 accountId, uint128 marketId, uint32 maturityTimestamp) internal {
        IProductIRSModule(Config.load().VOLTZ_V2_DATED_IRS_PROXY).settle(accountId, marketId, maturityTimestamp);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Object for tracking accounts with access control and collateral tracking.
 */
library Account {

    struct Exposure {
        // productId (IRS) -> marketID (aUSDC lend) -> maturity (30th December)
        // productId (Dated Future) -> marketID (BTC) -> maturity (30th December)
        // productId (Perp) -> marketID (ETH)
        // note, we don't neeed to keep track of the maturity for the purposes of of IM, LM calc
        // because the risk parameter is shared across maturities for a given productId marketId pair
        // uint128 productId; -> since already have it in the exposures mapping
        uint128 marketId;
        int256 filled;
        // this value should technically be uint256, however using int256 to minimise need for casting
        // todo: consider using uint256 for the below values since they should never be negative
        int256 unfilledLong;
        int256 unfilledShort;
    }
}

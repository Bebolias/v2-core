//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../interfaces/IProduct.sol";

/// @title Interface of a base dated product
interface IBaseDatedProduct is IProduct {
    // process taker and maker orders & single pool
    // settle

    /**
     * @notice Returns the address that owns a given account, as recorded by the protocol.
     * @param accountId Id of the account that wants to settle
     * @param marketId Id of the market in which the account wants to settle (e.g. 1 for aUSDC lend)
     * @param maturityTimestamp Maturity timestamp of the market in which the account wants to settle
     */
    function settle(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external view;
}

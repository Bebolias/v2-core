/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import "../../src/interfaces/IPool.sol";

contract MockPool is IPool {
    int256 baseBalancePool;
    int256 quoteBalancePool;
    uint256 unfilledBaseLong;
    uint256 unfilledBaseShort;
    mapping(uint256 => UD60x18) datedIRSTwaps;

    function name(uint128 poolId) external view returns (string memory) {
        return "mockpool";
    }

    function executeDatedTakerOrder(
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 baseAmount,
        uint160 priceLimit
    )
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount)
    {
        executedBaseAmount = baseAmount;
        executedQuoteAmount = baseAmount;
    }

    function setBalances(
        int256 _baseBalancePool,
        int256 _quoteBalancePool,
        uint256 _unfilledBaseLong,
        uint256 _unfilledBaseShort
    )
        external
    {
        baseBalancePool = _baseBalancePool;
        quoteBalancePool = _quoteBalancePool;
        unfilledBaseLong = _unfilledBaseLong;
        unfilledBaseShort = _unfilledBaseShort;
    }

    function getAccountFilledBalances(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId
    )
        external
        view
        returns (int256, int256)
    {
        return (baseBalancePool, quoteBalancePool);
    }

    function getAccountUnfilledBases(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId
    )
        external
        view
        returns (uint256, uint256)
    {
        return (unfilledBaseLong, unfilledBaseShort);
    }

    function closeUnfilledBase(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId
    )
        external
        returns (int256 closedBasePool)
    {
        closedBasePool = baseBalancePool;

        baseBalancePool = 0;
        quoteBalancePool = 0;
    }

    function getAdjustedDatedIRSTwap(
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 orderSize,
        uint32 lookbackWindow
    )
        external
        view
        returns (UD60x18)
    {
        return datedIRSTwaps[(marketId << 32) | maturityTimestamp];
    }

    function setDatedIRSTwap(uint128 marketId, uint32 maturityTimestamp, UD60x18 _datedIRSTwap) external {
        datedIRSTwaps[(marketId << 32) | maturityTimestamp] = _datedIRSTwap;
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/core/src/utils/contracts/interfaces/IERC165.sol";
import "../../src/interfaces/IPool.sol";

contract MockPool is IPool {
    int256 baseBalancePool;
    int256 quoteBalancePool;
    int256 unfilledBaseLong;
    int256 unfilledBaseShort;
    mapping(uint256 => uint256) datedIRSGwaps;

    function name(uint128 poolId) external view returns (string memory) {
        return "mockpool";
    }

    function executeDatedTakerOrder(
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 baseAmount
    )
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount)
    {
        executedBaseAmount = 0;
        executedQuoteAmount = 0;
    }

    function setBalances(
        int256 _baseBalancePool,
        int256 _quoteBalancePool,
        int256 _unfilledBaseLong,
        int256 _unfilledBaseShort
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
        returns (int256, int256)
    {
        return (unfilledBaseLong, unfilledBaseShort);
    }

    function closePosition(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId
    )
        external
        returns (int256 closedBasePool, int256 closedQuotePool) {
            closedBasePool = baseBalancePool;
            closedQuotePool = quoteBalancePool;
            
            baseBalancePool = 0;
            quoteBalancePool = 0;
    }

    function getDatedIRSGwap(uint128 marketId, uint32 maturityTimestamp) external view returns (uint256) {
        return datedIRSGwaps[(marketId << 32) | maturityTimestamp];
    }

    function setDatedIRSGwap(uint128 marketId, uint32 maturityTimestamp, uint256 _datedIRSGwap) external {
        datedIRSGwaps[(marketId << 32) | maturityTimestamp] = _datedIRSGwap;
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return true;
    }
}

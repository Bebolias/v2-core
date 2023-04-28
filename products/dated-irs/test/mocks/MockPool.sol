// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import "../../src/interfaces/IPool.sol";

contract MockPool is IPool {
    int256 baseBalancePool;
    int256 quoteBalancePool;
    uint256 unfilledBaseLong;
    uint256 unfilledBaseShort;
    mapping(uint256 => UD60x18) datedIRSGwaps;

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

    function closePosition(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId
    )
        external
        returns (int256 closedBasePool, int256 closedQuotePool)
    {
        closedBasePool = baseBalancePool;
        closedQuotePool = quoteBalancePool;

        baseBalancePool = 0;
        quoteBalancePool = 0;
    }

    function getDatedIRSGwap(uint128 marketId, uint32 maturityTimestamp) external view returns (UD60x18) {
        return datedIRSGwaps[(marketId << 32) | maturityTimestamp];
    }

    function setDatedIRSGwap(uint128 marketId, uint32 maturityTimestamp, UD60x18 _datedIRSGwap) external {
        datedIRSGwaps[(marketId << 32) | maturityTimestamp] = _datedIRSGwap;
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return true;
    }
}

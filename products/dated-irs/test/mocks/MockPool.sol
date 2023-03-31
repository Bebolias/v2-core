// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import "../../src/interfaces/IPool.sol";
import { SD59x18, ZERO } from "@prb/math/SD59x18.sol";

contract MockPool is IPool {
    SD59x18 baseBalancePool;
    SD59x18 quoteBalancePool;
    SD59x18 unfilledBaseLong;
    SD59x18 unfilledBaseShort;
    mapping(uint256 => UD60x18) datedIRSGwaps;

    function name(uint128 poolId) external view returns (string memory) {
        return "mockpool";
    }

    function executeDatedTakerOrder(
        uint128 marketId,
        uint32 maturityTimestamp,
        SD59x18 baseAmount
    )
        external
        returns (SD59x18 executedBaseAmount, SD59x18 executedQuoteAmount)
    {
        executedBaseAmount = ZERO;
        executedQuoteAmount = ZERO;
    }

    function setBalances(
        SD59x18 _baseBalancePool,
        SD59x18 _quoteBalancePool,
        SD59x18 _unfilledBaseLong,
        SD59x18 _unfilledBaseShort
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
        returns (SD59x18, SD59x18)
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
        returns (SD59x18, SD59x18)
    {
        return (unfilledBaseLong, unfilledBaseShort);
    }

    function closePosition(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId
    )
        external
        returns (SD59x18 closedBasePool, SD59x18 closedQuotePool) {
            closedBasePool = baseBalancePool;
            closedQuotePool = quoteBalancePool;
            
            baseBalancePool = ZERO;
            quoteBalancePool = ZERO;
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

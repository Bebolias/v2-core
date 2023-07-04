/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "../../src/storage/RateOracleReader.sol";
import "../mocks/MockRateOracle.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

contract ExposeRateOracleReader {
    using RateOracleReader for RateOracleReader.Data;

    // Exposed functions
    function load(uint128 id) external pure returns (bytes32 s) {
        RateOracleReader.Data storage oracle = RateOracleReader.load(id);
        assembly {
            s := oracle.slot
        }
    }


    function loadRateIndexAtMaturity(uint128 id, uint32 maturityTimestamp) external view returns (UD60x18 index) {
        RateOracleReader.Data storage oracleData = RateOracleReader.load(id);
        index = oracleData.rateIndexAtMaturity[maturityTimestamp];
    }

    function create(uint128 marketId, address oracleAddress, uint256 maturityIndexCachingWindowInSeconds) external
    returns (bytes32 s) {
        RateOracleReader.Data storage oracle = RateOracleReader.set(marketId, oracleAddress,
            maturityIndexCachingWindowInSeconds);
        assembly {
            s := oracle.slot
        }
    }

    function updateRateIndexAtMaturityCache(uint128 id, uint32 maturityTimestamp) external {
        RateOracleReader.load(id).updateRateIndexAtMaturityCache(maturityTimestamp);
    }

    function backfillRateIndexAtMaturityCache(uint128 id, uint32 maturityTimestamp, UD60x18 rateIndexAtMaturity) external {
        RateOracleReader.load(id).backfillRateIndexAtMaturityCache(maturityTimestamp, rateIndexAtMaturity);
    }

    function getRateIndexCurrent(uint128 id) external returns (UD60x18) {
        RateOracleReader.Data storage oracle = RateOracleReader.load(id);
        return oracle.getRateIndexCurrent();
    }

    function getRateIndexMaturity(uint128 id, uint32 maturityTimestamp) external returns (UD60x18) {
        RateOracleReader.Data storage oracle = RateOracleReader.load(id);
        return oracle.getRateIndexMaturity(maturityTimestamp);
    }
}

contract RateOracleReaderTest is Test {
    using { unwrap } for UD60x18;

    using RateOracleReader for RateOracleReader.Data;

    ExposeRateOracleReader rateOracleReader;

    MockRateOracle mockRateOracle;
    uint32 public maturityTimestamp;

    uint32 internal constant ONE_YEAR = 3139000;
    uint128 internal constant marketId = 100;
    bytes32 internal constant rateOracleSlot = keccak256(abi.encode("xyz.voltz.RateOracleReader", marketId));

    function setUp() public virtual {
        rateOracleReader = new ExposeRateOracleReader();
        mockRateOracle = new MockRateOracle();
        maturityTimestamp = Time.blockTimestampTruncated() + ONE_YEAR;
        rateOracleReader.create(100, address(mockRateOracle), 3600);
    }

    function test_LoadAtCorrectStorageSlot() public {
        bytes32 slot = rateOracleReader.load(marketId);
        assertEq(slot, rateOracleSlot);
    }

    function test_CreatedAtCorrectStorageSlot() public {
        bytes32 slot = rateOracleReader.create(200, address(mockRateOracle), 3600);
        assertEq(slot, keccak256(abi.encode("xyz.voltz.RateOracleReader", 200)));
    }

    function test_UpdateCacheAfterMaturityWithNoPreviousCache() public {
        vm.warp(maturityTimestamp + 3599);

        uint256 indexToSet = 1.001e18;

        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        UD60x18 index = rateOracleReader.loadRateIndexAtMaturity(marketId, maturityTimestamp);

        assertEq(index.unwrap(), indexToSet);
    }


    function test_GetRateIndexCurrentBeforeMaturity() public {
        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        UD60x18 index = rateOracleReader.getRateIndexCurrent(marketId);
        assertEq(index.unwrap(), indexToSet);
    }


    function test_GetRateIndexCurrentAfterMaturityZeroCacheAtMaturity() public {
        vm.warp(maturityTimestamp + 1);
        rateOracleReader.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);

        UD60x18 index = rateOracleReader.getRateIndexCurrent(marketId);

        assertEq(index.unwrap(), indexToSet);
    }


    function test_RevertWhen_GetRateIndexMaturityBeforeMaturity() public {
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityNotReached.selector));
        UD60x18 index = rateOracleReader.getRateIndexMaturity(marketId, maturityTimestamp);
    }

    function test_GetRateIndexMaturityAfterMaturity() public {
        vm.warp(maturityTimestamp + 1);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateRateIndexAtMaturityCache(marketId, maturityTimestamp); // update at-maturity cache

        UD60x18 index = rateOracleReader.getRateIndexMaturity(marketId, maturityTimestamp);
        assertEq(index.unwrap(), indexToSet);
    }

    function test_BackfillRateIndexAtMaturityCache() public {
        vm.warp(maturityTimestamp + 3601);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.backfillRateIndexAtMaturityCache(marketId, maturityTimestamp, ud(indexToSet));

        UD60x18 index = rateOracleReader.loadRateIndexAtMaturity(marketId, maturityTimestamp);
        assertEq(index.unwrap(), indexToSet);
    }

    function test_RevertWhen_BackfillRateIndexAtMaturityCacheDuringCachingWindow() public {
        vm.warp(maturityTimestamp + 3599);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityIndexCachingWindowOngoing.selector));
        rateOracleReader.backfillRateIndexAtMaturityCache(marketId, maturityTimestamp, ud(indexToSet));
    }

    function test_RevertWhen_BackfillRateIndexAtMaturityCacheBeforeMaturity() public {
        vm.warp(maturityTimestamp - 1);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityNotReached.selector));
        rateOracleReader.backfillRateIndexAtMaturityCache(marketId, maturityTimestamp, ud(indexToSet));
    }

    function test_RevertWhen_UpdateRateIndexAtMaturityCacheBeforeMaturity() public {
        vm.warp(maturityTimestamp - 1);

        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityNotReached.selector));
        rateOracleReader.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);
    }

    function test_RevertWhen_UpdateRateIndexAtMaturityCacheAfterCachingWindow() public {
        vm.warp(maturityTimestamp + 3601);

        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityIndexCachingWindowElapsed.selector));
        rateOracleReader.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);
    }

    function test_GetRateIndexMaturity() public {
        vm.warp(maturityTimestamp + 1);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        UD60x18 index = rateOracleReader.getRateIndexMaturity(marketId, maturityTimestamp);
        assertEq(index.unwrap(), indexToSet);
    }

}

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/storage/RateOracleReader.sol";
import "./mocks/MockRateOracle.sol";
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

    function loadRateIndexPreMaturity(uint128 id, uint256 maturityTimestamp) external view returns 
        (uint40 timestamp, UD60x18 index) {
        RateOracleReader.Data storage oracleData = RateOracleReader.load(id);
        RateOracleReader.PreMaturityData memory rateIndexOfMaturity = oracleData.rateIndexPreMaturity[maturityTimestamp];
        timestamp = rateIndexOfMaturity.lastKnownTimestamp;
        index = rateIndexOfMaturity.lastKnownIndex;
    }

    function loadRateIndexAtMaturity(uint128 id, uint256 maturityTimestamp) external view returns 
        (UD60x18 index) {
        RateOracleReader.Data storage oracleData = RateOracleReader.load(id);
        index = oracleData.rateIndexAtMaturity[maturityTimestamp];
    }

    function create(uint128 marketId, address oracleAddress) external returns (bytes32 s) {
        RateOracleReader.Data storage oracle = RateOracleReader.create(marketId, oracleAddress);
        assembly {
            s := oracle.slot
        }
    }

    function updateCache(uint128 id, uint256 maturityTimestamp) external {
        RateOracleReader.load(id).updateCache(maturityTimestamp);
    }

    function getRateIndexCurrent(uint128 id, uint256 maturityTimestamp) external returns (UD60x18) {
        RateOracleReader.Data storage oracle = RateOracleReader.load(id);
        return oracle.getRateIndexCurrent(maturityTimestamp);
    }

    function getRateIndexMaturity(uint128 id, uint256 maturityTimestamp) external returns (UD60x18) {
        RateOracleReader.Data storage oracle = RateOracleReader.load(id);
        return oracle.getRateIndexMaturity(maturityTimestamp);
    }
}

contract RateOracleReaderTest is Test {
    using { unwrap } for UD60x18;

    using RateOracleReader for RateOracleReader.Data;

    ExposeRateOracleReader rateOracleReader;

    MockRateOracle mockRateOracle;
    uint256 public maturityTimestamp;

    uint128 internal constant ONE_YEAR = 3139000;
    uint128 internal constant marketId = 100;
    bytes32 internal constant rateOracleSlot = keccak256(abi.encode("xyz.voltz.RateOracleReader", marketId));

    function setUp() public virtual {
        rateOracleReader = new ExposeRateOracleReader();
        mockRateOracle = new MockRateOracle();
        maturityTimestamp = block.timestamp + ONE_YEAR;
        rateOracleReader.create(100, address(mockRateOracle));
    }

    function test_CreatedAtCorrectStorageSlot() public {
        bytes32 slot = rateOracleReader.load(marketId);
        assertEq(slot, rateOracleSlot);
    }

    function test_UpdateCacheAfterMaturityWithNoPreviousCache() public {
        vm.warp(maturityTimestamp + ONE_YEAR);

        uint256 indexToSet = 1.001e18;

        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp);

        UD60x18 index  = rateOracleReader.loadRateIndexAtMaturity(marketId, maturityTimestamp);

        assertEq(index.unwrap(), indexToSet);
    }

    function test_UpdateCacheAfterMaturityWithZeroCacheValues() public {
        // update cache with index 0
        rateOracleReader.updateCache(marketId, maturityTimestamp);

        vm.warp(maturityTimestamp + ONE_YEAR);

        uint256 indexToSet = 1.001e18;

        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp);

        UD60x18 index  = rateOracleReader.loadRateIndexAtMaturity(marketId, maturityTimestamp);

        assertEq(index.unwrap(), indexToSet/2);
    }

    function test_UpdateCacheBeforeMaturityWithNoCache() public {
        vm.warp(maturityTimestamp - ONE_YEAR/2);

        uint256 indexToSet = 1.001e18;

        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp);

        (uint40 timestamp, UD60x18 index)  = rateOracleReader.loadRateIndexPreMaturity(marketId, maturityTimestamp);

        assertEq(index.unwrap(), indexToSet);
    }

    function test_UpdateCacheBeforeMaturityWithZeroCacheValues() public {
        // update cache with index 0
        rateOracleReader.updateCache(marketId, maturityTimestamp); // time 1

        vm.warp(maturityTimestamp/2 - 1); // should not trigger cahche update

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp);
        (uint40 timestamp0, UD60x18 index0)  = rateOracleReader.loadRateIndexPreMaturity(marketId, maturityTimestamp);
        assertEq(index0.unwrap(), 0);

        vm.warp(maturityTimestamp/2 + 1); // should not trigger cahche update

        rateOracleReader.updateCache(marketId, maturityTimestamp);
        (uint40 timestamp1, UD60x18 index1)  = rateOracleReader.loadRateIndexPreMaturity(marketId, maturityTimestamp);
        assertEq(index1.unwrap(), indexToSet);
    }

    function test_GetRateIndexCurrentBeforeMaturity() public {
        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp);
        UD60x18 index = rateOracleReader.getRateIndexCurrent(marketId, maturityTimestamp);
        assertEq(index.unwrap(), indexToSet);
    }

    function test_RevertWhen_UpdateCacheAfterMaturityZeroCache() public {
        vm.warp(maturityTimestamp + 1);
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MissingRateIndexAtMaturity.selector));
        UD60x18 index  = rateOracleReader.getRateIndexCurrent(marketId, maturityTimestamp);
    }

    function test_GetRateIndexCurrentAfterMaturityZeroCacheAtMaturity() public {
        // can also test expectCall() to rate oracle
        vm.warp(maturityTimestamp/2 - 1);
        rateOracleReader.updateCache(marketId, maturityTimestamp); // update pre-maturity cache (index = 0)

        vm.warp(maturityTimestamp + 1);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);

        UD60x18 index  = rateOracleReader.getRateIndexCurrent(marketId, maturityTimestamp);

        assertEq(index.unwrap(), indexToSet/2);
    }

    function test_GetRateIndexCurrentAfterMaturityCacheAtMaturity() public {
        // can also test expectCall() to rate oracle
        vm.warp(maturityTimestamp + 1);
        uint256 indexToSet0 = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet0 * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp); // update at-maturity cache (index = 0)

        vm.warp(maturityTimestamp + 2);
        uint256 indexToSet1 = 3.003e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet1 * 1e9);

        UD60x18 index  = rateOracleReader.getRateIndexCurrent(marketId, maturityTimestamp);

        assertEq(index.unwrap(), indexToSet0);
    }

    function test_RevertWhen_GetRateIndexMaturityBeforeMaturity() public {
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityNotReached.selector));
        UD60x18 index  = rateOracleReader.getRateIndexMaturity(marketId, maturityTimestamp);
    }

    function test_GetRateIndexMaturityAfterMaturity() public {
        vm.warp(maturityTimestamp + 1);

        uint256 indexToSet = 1.001e18;
        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleReader.updateCache(marketId, maturityTimestamp); // update at-maturity cache

        UD60x18 index  = rateOracleReader.getRateIndexMaturity(marketId, maturityTimestamp);
        assertEq(index.unwrap(), indexToSet);
    }
}
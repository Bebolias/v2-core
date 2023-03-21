pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./mocks/MockRateOracle.sol";
import "../src/oracles/AaveRateOracle.sol";
import "../src/modules/RateOracleManager.sol";
import "../src/storage/RateOracleReader.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

contract RateOracleManagerTestBase is Test {
    RateOracleManager rateOracleManager;
    using RateOracleReader for RateOracleReader.Data;

    event RateOracleRegistered(uint128 indexed marketId, address indexed oracleAddress);

    MockRateOracle mockRateOracle;
    uint256 public maturityTimestamp;

    function setUp() public virtual {
        rateOracleManager = new RateOracleManager();
        MockAaveLendingPool lendingPool = new MockAaveLendingPool();
        AaveRateOracle aaveOracle = new AaveRateOracle(lendingPool, address(0));
        mockRateOracle = new MockRateOracle();
        maturityTimestamp = block.timestamp + 3139000;
        rateOracleManager.registerVariableOracle(100, address(mockRateOracle));
    }
}


contract RateOracleManagerTest is RateOracleManagerTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_initRegisterVariableOracle() public {
        // expect RateOracleRegistered event
        vm.expectEmit(true, true, false, true);
        emit RateOracleRegistered(100, address(mockRateOracle));

        rateOracleManager.registerVariableOracle(100, address(mockRateOracle));
    }

    function test_initGetRateIndexCurrent() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        assertEq(unwrap(rateIndexCurrent), 0);
    }

    function test_getRateIndexCurrent_beforeMaturity() public {
        mockRateOracle.setLastUpdatedIndex(1.001e18 * 1e9);
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        assertEq(unwrap(rateIndexCurrent), 1.001e18);
    }

    function test_fail_getRateIndexCurrent_afterMaturity() public {
        vm.warp(maturityTimestamp + 1);
        vm.expectRevert();
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        // fails because of no cache update
    }

    function test_fail_getRateIndexMaturity_afterMaturity() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
    }

    function test_getRateIndexMaturity_beforeMaturity() public {
        mockRateOracle.setLastUpdatedIndex(1.001e18 * 1e9);
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        assertEq(unwrap(rateIndexCurrent), 1.001e18);
    }
}
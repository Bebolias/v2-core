pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./mocks/MockRateOracle.sol";
import "../src/oracles/AaveRateOracle.sol";
import "../src/modules/RateOracleManager.sol";
import "../src/storage/RateOracleReader.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

contract RateOracleManagerTest is Test {
    using { unwrap } for UD60x18;

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
    
    function test_InitRegisterVariableOracle() public {
        // expect RateOracleRegistered event
        vm.expectEmit(true, true, false, true);
        emit RateOracleRegistered(100, address(mockRateOracle));

        rateOracleManager.registerVariableOracle(100, address(mockRateOracle));
    }

    function test_InitGetRateIndexCurrent() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        assertEq(rateIndexCurrent.unwrap(), 0);
    }

    function test_GetRateIndexCurrentBeforeMaturity() public {
        mockRateOracle.setLastUpdatedIndex(1.001e18 * 1e9);
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        assertEq(rateIndexCurrent.unwrap(), 1.001e18);
    }

    function test_RevertWhen_NoCacheAfterMaturity() public {
        vm.warp(maturityTimestamp + 1);
        vm.expectRevert();
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
        // fails because of no cache update
    }

    function test_NoCacheBeforeMaturity() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(100, maturityTimestamp);
    }
}
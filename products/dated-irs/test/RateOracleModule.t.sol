pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./mocks/MockAaveLendingPool.sol";
import "src/products/dated-irs/oracles/AaveRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, convert, ud } from "@prb/math/UD60x18.sol";
import { PRBMathAssertions } from "@prb/math/test/Assertions.sol";
import { console2 } from "forge-std/console2.sol";

contract RateOracleManagerTestBase is Test, PRBMathAssertions {
    RateOracleManager rateOracleManager;
    using RateOracleReader for RateOracleReader.Data;

    function setUp() public virtual {
        rateOracleManager = new RateOracleManager();
        mockRateOracleReader = new MockRateOracleReader(); // how to initialise mock library
        rateOracleManager.registerVariableOracle(100, address(mockRateOracleReader));
        // set rate index
    }
}


contract RateOracleManagerTest is RateOracleManagerTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_getRateIndexCurrent() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(marketId, block.timestamp - 1);
        assertEq(rateIndexCurrent, 0);
    }

    function test_getRateIndexMaturity() public {
    }

    function test_registerVariableOracle() public {
    }

    function testFuzz_success_interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    ) public {}
}
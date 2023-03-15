pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./mocks/MockAaveLendingPool.sol";
import "src/products/dated-irs/oracles/AaveRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, convert, ud } from "@prb/math/UD60x18.sol";
import { PRBMathAssertions } from "@prb/math/test/Assertions.sol";
import { console2 } from "forge-std/console2.sol";

contract AaveRateOracle_Test_Base is Test, PRBMathAssertions {
    address constant TEST_UNDERLYING_ADDRESS = 0x1122334455667788990011223344556677889900;
    IERC20 constant TEST_UNDERLYING = IERC20(TEST_UNDERLYING_ADDRESS);
    UD60x18 initValue = convert(42);
    MockAaveLendingPool mockLendingPool;
    AaveRateOracle rateOracle;

    function setUp() public virtual {
        mockLendingPool = new MockAaveLendingPool();
        mockLendingPool.setReserveNormalizedIncome(TEST_UNDERLYING, initValue);
        rateOracle = new AaveRateOracle(mockLendingPool, TEST_UNDERLYING_ADDRESS);
    }
}

contract AaveRateOracle_Test1 is AaveRateOracle_Test_Base {
    function setUp() public override {
        super.setUp();
    }

    function test_mock() public {
        assertEq(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS), 42e27);
    }

    function test_initialIndex() public {
        assertEq(rateOracle.getCurrentIndex(), initValue);
    }

    function test_initialIndexWithTime() public {
        (uint40 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertEq(index, initValue);
        assertEq(time, block.timestamp);
    }

    function test_interpolateIndexValue() public {
        UD60x18 index = rateOracle.getLastUpdatedIndex(
            ud(1e18), // UD60x18 beforeIndex
            0, // uint256 beforeTimestamp
            ud(1.1e18), // UD60x18 atOrAfterIndex
            100, // uint256 atOrAfterTimestamp
            50 // uint256 queryTimestamp
        );
        assertEq(index, ud(1.05e18));
    }

    function testFuzz_interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    ) public {
        vm.assume(beforeIndex <= atOrAfterIndex); // can it be equal? (affects below too)
        vm.assume(beforeTimestamp <= atOrAfterTimestamp);
        vm.assume(queryTimestamp <= atOrAfterTimestamp && queryTimestamp >= atOrAfterTimestamp);

        UD60x18 index = rateOracle.getLastUpdatedIndex(
            beforeIndex,
            beforeTimestamp,
            atOrAfterIndex,
            atOrAfterTimestamp,
            queryTimestamp
        );
        assertTrue(index >= beforeIndex); // does it need library for comparison?
        assertTrue(index <= atOrAfterIndex);

        // slopes should be equal
        assertEq(
            index.div(beforeIndex).div(queryTimestamp.sub(beforeTimestamp)),
            atOrAfterIndex.div(beforeIndex).div(atOrAfterTimestamp.sub(beforeTimestamp))
        );
    }
}

contract AaveRateOracle_Test2 is AaveRateOracle_Test_Base {
    function setUp() public override {
        super.setUp();
        // 1000000001000000000 for 0.0000001% per second = ~3.2% APY
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(1000000001000000000));
    }

    function testMock() public {
        // vm.skip(10000); // TODO
        assertEq(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS), 42e27);
    }

    function testInitialIndex() public {
        assertEq(rateOracle.getCurrentIndex(), initValue);
    }

    function testInitialIndexWithTime() public {
        (uint40 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertEq(index, initValue);
        assertEq(time, block.timestamp);
    }

    // TODO: test interpolation
}

// TO DO: fuzzying 
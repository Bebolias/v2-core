pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./mocks/MockAaveLendingPool.sol";
import "../src/oracles/AaveRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";
import { console2 } from "forge-std/console2.sol";

contract AaveRateOracle_Test_Base is Test {
    address constant TEST_UNDERLYING_ADDRESS = 0x1122334455667788990011223344556677889900;
    IERC20 constant TEST_UNDERLYING = IERC20(TEST_UNDERLYING_ADDRESS);
    UD60x18 initValue = ud(1e18);
    MockAaveLendingPool mockLendingPool;
    AaveRateOracle rateOracle;

    function setUp() public virtual {
        mockLendingPool = new MockAaveLendingPool();
        mockLendingPool.setReserveNormalizedIncome(TEST_UNDERLYING, initValue);
        rateOracle = new AaveRateOracle(mockLendingPool, TEST_UNDERLYING_ADDRESS);
    }
}

// TODO: test when index gets smaller -> shold fail

contract AaveRateOracle_Test1 is AaveRateOracle_Test_Base {
    function setUp() public override {
        super.setUp();
    }

    function test_mock() public {
        assertEq(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS), 42e27);
    }

    function test_initialIndex() public {
        assertEq(unwrap(rateOracle.getCurrentIndex()), unwrap(initValue));
    }

    function test_initialIndexWithTime() public {
        (uint40 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertEq(unwrap(index), unwrap(initValue));
        assertEq(time, block.timestamp);
    }

    function test_interpolateIndexValue() public {
        UD60x18 index = rateOracle.interpolateIndexValue(
            ud(1e18), // UD60x18 beforeIndex
            0, // uint256 beforeTimestamp
            ud(1.1e18), // UD60x18 atOrAfterIndex
            100, // uint256 atOrAfterTimestamp
            50 // uint256 queryTimestamp
        );
        assertEq(unwrap(index), 1.05e18);
    }

    function testFuzz_success_interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    ) public {
        vm.assume(beforeIndex.lt(atOrAfterIndex)); // can it be equal? (affects below too)
        vm.assume(beforeTimestamp <= atOrAfterTimestamp);
        vm.assume(queryTimestamp <= atOrAfterTimestamp && queryTimestamp >= atOrAfterTimestamp);

        UD60x18 index = rateOracle.interpolateIndexValue(
            beforeIndex,
            beforeTimestamp,
            atOrAfterIndex,
            atOrAfterTimestamp,
            queryTimestamp
        );
        assertTrue(index.gte(beforeIndex)); // does it need library for comparison?
        assertTrue(index.lte(atOrAfterIndex));

        // slopes should be equal
        assertEq(
            unwrap(index.div(beforeIndex).div(ud(queryTimestamp - beforeTimestamp))),
            unwrap(atOrAfterIndex.div(beforeIndex).div(ud(atOrAfterTimestamp - beforeTimestamp)))
        );
    }

    /**
    * @dev should fail in the following cases:
    * - give a negative index if before & at values are inverted (time & index)
    * - 
    */
    function testFuzz_fail_interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    ) public {
        vm.expectRevert();
        vm.assume(
            beforeIndex.gte(atOrAfterIndex) ||
            beforeTimestamp > atOrAfterTimestamp ||
            !(queryTimestamp <= atOrAfterTimestamp && queryTimestamp >= atOrAfterTimestamp)
        );

        UD60x18 index = rateOracle.interpolateIndexValue(
            beforeIndex,
            beforeTimestamp,
            atOrAfterIndex,
            atOrAfterTimestamp,
            queryTimestamp
        );
    }
}

contract AaveRateOracle_Test2 is AaveRateOracle_Test_Base {
    uint256 constant FACTOR_PER_SECOND = 1000000001000000000;
    function setUp() public override {
        super.setUp();
        // 1000000001000000000 for 0.0000001% per second = ~3.2% APY
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
    }

    function test_Mock() public {
        ////vm.skip(10000); // TODO: not sure how this behaves, assuming it starts a new node per test
        uint256 expectedCurrentIndex = unwrap(initValue) + 499e7;
        assertApproxEqRel(
            mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS),
            expectedCurrentIndex,
            1e7 // 0.000000001% error
        );
    }

    function test_InitialIndex() public {
        //vm.skip(10000); // TODO: not sure how this behaves, assuming it starts a new node per test
        uint256 expectedCurrentIndex = unwrap(initValue) + 499e7;
        assertApproxEqRel(unwrap(rateOracle.getCurrentIndex()), expectedCurrentIndex, 1e7);
    }

    function test_InitialIndexWithTime() public {
        //vm.skip(10000); // TODO: not sure how this behaves, assuming it starts a new node per test
        (uint40 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        uint256 expectedCurrentIndex = unwrap(initValue) + 499e7;
        assertApproxEqRel(unwrap(index), unwrap(initValue), 1e17);
        assertEq(time, block.timestamp);
    }

    function testFuzz_Mock(uint256 factorPerSecond, uint16 timePassed) public {
        vm.assume(factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        //vm.skip(timePassed); 
        assertTrue(
            mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS) >= unwrap(initValue)
        );
    }

    function testFuzz_CurrentIndex(uint256 factorPerSecond, uint16 timePassed) public {
        vm.assume(factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        //vm.skip(timePassed);
        assertTrue(rateOracle.getCurrentIndex().gte(initValue));
    }

    function testFuzz_InitialIndexWithTime(uint256 factorPerSecond, uint16 timePassed) public {
        vm.assume(factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        //vm.skip(timePassed);
        (uint40 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertTrue(index.gte(initValue));
        assertEq(time, block.timestamp);
    }
}
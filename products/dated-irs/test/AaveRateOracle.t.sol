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
        assertEq(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS), unwrap(initValue) * 1e9);
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

    // function testFuzz_success_interpolateIndexValue(
    //     uint256 beforeIndex,
    //     uint40 beforeTimestamp,
    //     uint256 atOrAfterIndex,
    //     uint40 atOrAfterTimestamp,
    //     uint40 queryTimestamp
    // ) public {
    //     // bounding not to lose precision
    //     // should we also enforce this in the function?
    //     vm.assume(atOrAfterIndex < 1e38);
    //     vm.assume(beforeIndex >= 1 && beforeTimestamp >= 1 && beforeIndex >= 1e18);

    //     vm.assume(beforeIndex < atOrAfterIndex);
    //     vm.assume(queryTimestamp <= atOrAfterTimestamp && queryTimestamp > beforeTimestamp);

    //     UD60x18 beforeIndexWad = ud(beforeIndex);
    //     UD60x18 atOrAfterIndexWad = ud(atOrAfterIndex);
    //     uint256 beforeTimestampWad = beforeTimestamp * 1e18;
    //     uint256 atOrAfterTimestampWad = atOrAfterTimestamp * 1e18;
    //     uint256 queryTimestampWad = queryTimestamp * 1e18;

    //     UD60x18 index = rateOracle.interpolateIndexValue(
    //         beforeIndexWad,
    //         beforeTimestampWad,
    //         atOrAfterIndexWad,
    //         atOrAfterTimestampWad,
    //         queryTimestampWad
    //     );

    //     assertTrue(index.gte(beforeIndexWad)); // does it need library for comparison?
    //     assertTrue(index.lte(atOrAfterIndexWad));

    //     console2.log("index:", unwrap(index));

    //     // slopes should be equal
    //     if(unwrap(index.sub(beforeIndexWad).div(index)) < 1e9) {
    //         console2.log("time:", unwrap(ud(beforeTimestampWad).div(ud(atOrAfterTimestampWad))));
    //         console2.log("index dif:", unwrap(beforeIndexWad.div(atOrAfterIndexWad)));
    //         assertTrue(
    //             unwrap(ud(beforeTimestampWad).div(ud(atOrAfterTimestampWad))) < 1e9
    //             || unwrap(beforeIndexWad.div(atOrAfterIndexWad)) < 1e9
    //         );
    //     } else {
    //         console2.log("ok");
    //         assertApproxEqRel(
    //             unwrap(atOrAfterIndexWad.sub(beforeIndexWad).div(index.sub(beforeIndexWad))),
    //             unwrap(ud(atOrAfterTimestampWad - beforeTimestampWad).div(ud(queryTimestampWad - beforeTimestampWad))),
    //             5e16 // 5% error
    //         );
    //     }
        
    // }

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
        vm.assume(atOrAfterTimestamp != queryTimestamp);
        vm.assume(
            beforeIndex.gt(atOrAfterIndex) ||
            beforeTimestamp >= atOrAfterTimestamp ||
            (queryTimestamp > atOrAfterTimestamp || queryTimestamp <= beforeTimestamp)
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
    uint256 constant INDEX_AFTER_SET_TIME = 1000010000050000000;
    function setUp() public override {
        super.setUp();
        // 1000000001000000000 for 0.0000001% per second = ~3.2% APY
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
    }

    function test_Mock() public {
        vm.warp(block.timestamp + 10000);// TODO: not sure how this behaves, assuming it starts a new node per test
        assertApproxEqRel(
            mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS),
            INDEX_AFTER_SET_TIME * 1e9, 
            1e7 // 0.000000001% error
        );
    }

    function test_InitialIndex() public {
        vm.warp(block.timestamp + 10000); // TODO: not sure how this behaves, assuming it starts a new node per test
        assertApproxEqAbs(unwrap(rateOracle.getCurrentIndex()), INDEX_AFTER_SET_TIME, 1e7);
    }

    function test_InitialIndexWithTime() public {
        vm.warp(block.timestamp + 10000);
        (uint40 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertApproxEqRel(unwrap(index), INDEX_AFTER_SET_TIME, 1e17);
        assertEq(time, block.timestamp);
    }

    function testFuzz_Mock(uint256 factorPerSecond, uint16 timePassed) public {
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(block.timestamp + timePassed);
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
/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "../mocks/MockAaveLendingPool.sol";
import "../../src/oracles/AaveV3RateOracle.sol";
import "../../src/interfaces/IRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

contract AaveV3RateOracleTest is Test {
    using { unwrap } for UD60x18;

    address constant TEST_UNDERLYING_ADDRESS = 0x1122334455667788990011223344556677889900;
    IERC20 constant TEST_UNDERLYING = IERC20(TEST_UNDERLYING_ADDRESS);
    uint256 constant FACTOR_PER_SECOND = 1000000001000000000;
    uint256 constant INDEX_AFTER_SET_TIME = 1000010000050000000;
    UD60x18 initValue = ud(1e18);

    MockAaveLendingPool mockLendingPool;
    AaveV3RateOracle rateOracle;

    function setUp() public virtual {
        mockLendingPool = new MockAaveLendingPool();
        mockLendingPool.setReserveNormalizedIncome(TEST_UNDERLYING, initValue);
        rateOracle = new AaveV3RateOracle(
            mockLendingPool,
            TEST_UNDERLYING_ADDRESS
        );
    }

    function test_SetIndexInMock() public {
        assertEq(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS), initValue.unwrap() * 1e9);
    }

    function test_InitCurrentIndex() public {
        assertEq(rateOracle.getCurrentIndex().unwrap(), initValue.unwrap());
    }

    function test_InitLastUpdatedIndex() public {
        (uint32 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertEq(index.unwrap(), initValue.unwrap());
        assertEq(time, Time.blockTimestampTruncated());
    }


    function test_SetNonZeroIndexInMock() public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        vm.warp(Time.blockTimestampTruncated() + 10000);
        assertApproxEqRel(
            mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS),
            INDEX_AFTER_SET_TIME * 1e9,
            1e7 // 0.000000001% error
        );
    }

    function test_NonZeroCurrentIndex() public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        vm.warp(Time.blockTimestampTruncated() + 10000);
        assertApproxEqAbs(rateOracle.getCurrentIndex().unwrap(), INDEX_AFTER_SET_TIME, 1e7);
    }

    function test_NonZeroLastUpdatedIndex() public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        vm.warp(Time.blockTimestampTruncated() + 10000);

        (uint32 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();

        assertApproxEqRel(index.unwrap(), INDEX_AFTER_SET_TIME, 1e17);
        assertEq(time, Time.blockTimestampTruncated());
    }

    function test_SupportsInterfaceIERC165() public {
        assertTrue(rateOracle.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterfaceIRateOracle() public {
        assertTrue(rateOracle.supportsInterface(type(IRateOracle).interfaceId));
    }

    function test_SupportsOtherInterfaces() public {
        assertFalse(rateOracle.supportsInterface(type(IERC20).interfaceId));
    }

    // ------------------- FUZZING -------------------


    function testFuzz_SetNonZeroIndexInMock(uint256 factorPerSecond, uint16 timePassed) public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(Time.blockTimestampTruncated() + timePassed);
        assertTrue(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS) >= initValue.unwrap());
    }

    function testFuzz_NonZeroCurrentIndexAfterTimePasses(uint256 factorPerSecond, uint16 timePassed) public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(Time.blockTimestampTruncated() + timePassed);

        UD60x18 index = rateOracle.getCurrentIndex();

        assertTrue(index.gte(initValue));
    }

    function testFuzz_NonZeroLatestUpdateAfterTimePasses(uint256 factorPerSecond, uint16 timePassed) public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(Time.blockTimestampTruncated() + timePassed);

        (uint32 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();

        assertTrue(index.gte(initValue));
        assertEq(time, Time.blockTimestampTruncated());
    }

}

pragma solidity 0.8.17;

import "./mocks/MockAaveLendingPool.sol";
import "src/products/dated-irs/oracles/AaveRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, convert, ud } from "@prb/math/UD60x18.sol";
import { PRBMathAssertions } from "@prb/math/test/Assertions.sol";
import { console2 } from "forge-std/console2.sol";

contract AaveRateOracle_Test_Base is PRBMathAssertions {
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

    function testMock() public {
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
}

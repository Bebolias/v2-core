pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import "@voltz-protocol/v2-vamm/utils/vamm-math/FullMath.sol";
import "@voltz-protocol/v2-vamm/utils/vamm-math/FixedPoint96.sol";
import {Account} from "@voltz-protocol/core/src/storage/Account.sol";
import {DatedIrsRouter, DatedIrsProxy} from "../../src/proxies/DatedIrs.sol";

contract TestUtils is Test {

    function assertAlmostEq(int256 a, int256 b, uint256 eps) public {
        assertGe(a, b - int256(eps));
        assertLe(a, b + int256(eps));
    }

    function assertAlmostEq(int256 a, uint256 b, uint256 eps) public {
        assertGe(a, int256(b - eps));
        assertLe(a, int256(b + eps));
    }

    function assertAlmostEq(uint256 a, uint256 b, uint256 eps) public {
        assertGe(a, b - eps);
        assertLe(a, b + eps);
    }

    function absUtil(int256 a) public returns (uint256){
        return a > 0 ? uint256(a) : uint256(-a);
    }

    function absOrZero(int256 a) public returns (uint256){
        return a < 0 ? uint256(-a) : 0;
    }

    function timeFactor(uint32 maturityTimestamp) public returns (uint256) {
        return (uint256(maturityTimestamp) - block.timestamp) * 1e18 / (365 * 24 * 60 * 60);
    } 

    function priceFromTick(int24 _tick) public returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(_tick);
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
        return FullMath.mulDiv(1e18, FixedPoint96.Q96, priceX96);
    } 

}

contract ExposureUtil {

    function getLpExpShort(uint128 accountId, address token, DatedIrsProxy datedIrsProxy) public returns (int256) {
        (,Account.Exposure[] memory makerExpLow,)= 
            datedIrsProxy.getAccountTakerAndMakerExposures(accountId, token);
        return makerExpLow[0].annualizedNotional;
    }

    function getLpExpLong(uint128 accountId, address token, DatedIrsProxy datedIrsProxy) public returns (int256) {
        (,,Account.Exposure[] memory makerExpHigh)= 
            datedIrsProxy.getAccountTakerAndMakerExposures(accountId, token);
        return makerExpHigh[0].annualizedNotional;
    }

    function getTraderExp(uint128 accountId, address token, DatedIrsProxy datedIrsProxy) public returns (int256) {
        (Account.Exposure[] memory takerExp,,)= 
            datedIrsProxy.getAccountTakerAndMakerExposures(accountId, token);
        return takerExp[0].annualizedNotional;
    }

}
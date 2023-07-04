pragma solidity >=0.8.19;

import "forge-std/Test.sol";

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

}
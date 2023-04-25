pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/storage/Position.sol";

contract PositionTest is Test {
    using Position for Position.Data;

    Position.Data position;

    function setUp() public virtual {
        position = Position.Data({ baseBalance: 167, quoteBalance: -67 });
    }

    function test_Update() public {
        position.update(10, 20);
        assertEq(position.baseBalance, 177);
        assertEq(position.quoteBalance, -47);
    }

    function test_Settle() public {
        position.settle();
        assertEq(position.baseBalance, 0);
        assertEq(position.quoteBalance, 0);
    }
}

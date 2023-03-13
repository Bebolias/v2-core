//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/storage/Collateral.sol";

contract ExposedCollateral {
    Collateral.Data internal item;

    constructor(uint256 balance) {
        item = Collateral.Data({balance: balance});
    }

    // Mock functions
    function get() external view returns (Collateral.Data memory) {
        return item;
    }

    // Exposed functions
    function increaseCollateralBalance(uint256 amount) external {
        Collateral.increaseCollateralBalance(item, amount);
    }

    function decreaseCollateralBalance(uint256 amount) external {
        Collateral.decreaseCollateralBalance(item, amount);
    }
}

contract CollateralTest is Test {
    function test_IncreaseCollateralBalance() public {
        // Collateral with 100 balance
        ExposedCollateral collateral = new ExposedCollateral(100e18);

        // Increase it by 200
        collateral.increaseCollateralBalance(200e18);

        // Expect balance of 300
        assertEq(collateral.get().balance, 300e18);
    }

    function test_DecreaseCollateralBalance() public {
        // Collateral with 300 balance
        ExposedCollateral collateral = new ExposedCollateral(300e18);

        // Increase it by 200
        collateral.decreaseCollateralBalance(200e18);

        // Expect balance of 100
        assertEq(collateral.get().balance, 100e18);
    }

    function test_revertWhen_NotEnoughBalanceToDecrease() public {
        // Collateral with 100 balance
        ExposedCollateral collateral = new ExposedCollateral(100e18);

        // Expect revert when decreasing by 200
        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, 200e18));
        collateral.decreaseCollateralBalance(200e18);
    }

    function testFuzz_IncreaseCollateralBalance(uint256 balance, uint256 amount) public {
        vm.assume(amount <= UINT256_MAX - balance);
        ExposedCollateral collateral = new ExposedCollateral(balance);

        collateral.increaseCollateralBalance(amount);

        assertEq(collateral.get().balance, balance + amount);
    }

    function testFuzz_DecreaseCollateralBalance(uint256 balance, uint256 amount) public {
        vm.assume(amount <= balance);
        ExposedCollateral collateral = new ExposedCollateral(balance);

        collateral.decreaseCollateralBalance(amount);

        assertEq(collateral.get().balance, balance - amount);
    }

    function testFuzz_revertWhen_NotEnoughBalanceToDecrease(uint256 balance, uint256 amount) public {
        vm.assume(amount > balance);

        ExposedCollateral collateral = new ExposedCollateral(balance);
        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, amount));

        collateral.decreaseCollateralBalance(amount);
    }
}

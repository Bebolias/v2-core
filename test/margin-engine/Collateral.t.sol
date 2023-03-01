//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/margin-engine/storage/Collateral.sol";

contract ExposedCollateral {
    using Collateral for Collateral.Data;
    
    Collateral.Data item;

    constructor(uint256 balanceD18) {
        item = Collateral.Data({
                balanceD18: balanceD18
            });
    }

    // Mock functions
    function get() external view returns (Collateral.Data memory) {
        return item;
    }

    // Exposed functions
    function increaseCollateralBalance(uint256 amountD18) external {
        item.increaseCollateralBalance(amountD18);
    }

    function decreaseCollateralBalance(uint256 amountD18) external {
        item.decreaseCollateralBalance(amountD18);
    }
}

contract CollateralTest is Test {
    function test_IncreaseCollateralBalance() public {
        ExposedCollateral collateral = new ExposedCollateral(100e18);
        collateral.increaseCollateralBalance(200e18);

        assertEq(collateral.get().balanceD18, 300e18);
    }

    function test_DecreaseCollateralBalance() public {
        ExposedCollateral collateral = new ExposedCollateral(300e18);
        collateral.decreaseCollateralBalance(200e18);

        assertEq(collateral.get().balanceD18, 100e18);
    }

    function test_revertWhen_NotEnoughBalanceToDecrease() public {
        ExposedCollateral collateral = new ExposedCollateral(100e18);
        vm.expectRevert();
        collateral.decreaseCollateralBalance(200e18);
    }

    function testFuzz_IncreaseCollateralBalance(uint256 balance, uint256 amount) public {
        vm.assume(amount <= UINT256_MAX - balance);
        ExposedCollateral collateral = new ExposedCollateral(balance);
        collateral.increaseCollateralBalance(amount);

        assertEq(collateral.get().balanceD18, balance + amount);
    }

    function testFuzz_DecreaseCollateralBalance(uint256 balance, uint256 amount) public {
        vm.assume(amount <= balance);
        ExposedCollateral collateral = new ExposedCollateral(balance);
        collateral.decreaseCollateralBalance(amount);
        
        assertEq(collateral.get().balanceD18, balance - amount);
    }

    function testFuzz_revertWhen_NotEnoughBalanceToDecrease(uint256 balance, uint256 amount) public {
        vm.assume(amount > balance);
        ExposedCollateral collateral = new ExposedCollateral(balance);
        vm.expectRevert();
        collateral.decreaseCollateralBalance(amount);
    }
}
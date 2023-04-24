//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/libraries/Payments.sol";

contract ExposedPayments {
    // exposed functions
    function pay(address token, address recipient, uint256 value) external {
        Payments.pay(token, recipient, value);
    }

    function wrapETH(address recipient, uint256 amount) external {
        Payments.wrapETH(recpient, amount);
    }

    function unwrapWETH9(address recipient, uint256 amountMinimum) external {
        Payments.unwrapWETH9(recipient, amountMinimum);
    }
}

contract PaymentsTest is Test {}

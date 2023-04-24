//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../src/modules/ExecutionModule.sol";

contract UniversalRouterTest is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 10 ** 18;

    ExecutionModule executionModule;
    MockERC20 erc20;
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

library Constants {
    address public constant PRODUCT_OWNER = 0xE33e34229C7a487c5534eCd969C251F46EAf9e29;

    address public constant ALICE = 0x110846169b058F7d039cFd25E8fe14e903f96e7F;

    address public constant TOKEN_0 = 0x9401F1dce663726B5c61D7022c3ADf89b6a7E9f6;
    address public constant TOKEN_1 = 0x53F5559AeCf0DAe6B03C743D374D93873549C1a5;
    address public constant TOKEN_UNKNOWN = 0x24b5Ab51907cB75374db2b16229B6f767FFf9E60;

    uint256 public constant DEFAULT_TOKEN_0_BALANCE = 10000e18;
    uint256 public constant DEFAULT_TOKEN_1_BALANCE = 10e18;

    uint256 public constant TOKEN_0_CAP = 100000e18;
    uint256 public constant TOKEN_1_CAP = 1000e18;
}

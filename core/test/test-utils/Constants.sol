/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

library Constants {
    address public constant PROXY_OWNER = 0xa791FBF256B2cc08BD8a7C706f0A4498F96E8CBB;
    address public constant FEES_COLLECTOR = 0xF9198fAA1A54A0099BA59E50fE3Aa143E0fdAA53;
    address public constant PERIPHERY = 0x3038aD857D884385e28659Ec2a668A03E3ad9FfD;

    address public constant PRODUCT_CREATOR = 0xDa5dC27D8e107AbAFd9D91A77508d3EC139B8b12;
    address public constant PRODUCT_OWNER = 0xE33e34229C7a487c5534eCd969C251F46EAf9e29;

    address public constant ALICE = 0x110846169b058F7d039cFd25E8fe14e903f96e7F;
    address public constant BOB = 0xD74B3Fa2D0e1753779C1a29F3F25f68fc4e4d68c;

    address public constant TOKEN_0 = 0x9401F1dce663726B5c61D7022c3ADf89b6a7E9f6;
    address public constant TOKEN_1 = 0x53F5559AeCf0DAe6B03C743D374D93873549C1a5;
    address public constant TOKEN_UNKNOWN = 0x24b5Ab51907cB75374db2b16229B6f767FFf9E60;

    uint256 public constant DEFAULT_TOKEN_0_BALANCE = 10000e18;
    uint256 public constant DEFAULT_TOKEN_1_BALANCE = 10e18;

    uint256 public constant TOKEN_0_LIQUIDATION_BOOSTER = 10e18;
    uint256 public constant TOKEN_1_LIQUIDATION_BOOSTER = 4e17;
    uint256 public constant TOKEN_0_CAP = 100000e18;
    uint256 public constant TOKEN_1_CAP = 1000e18;
}

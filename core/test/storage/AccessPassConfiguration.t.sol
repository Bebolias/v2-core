/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/AccessPassConfiguration.sol";

contract ExposedAccessPassConfiguration {
    // Mock support
    function getAccessPassConfiguration() external pure returns (AccessPassConfiguration.Data memory) {
        return AccessPassConfiguration.load();
    }

    // Exposed functions
    function load() external pure returns (bytes32 s) {
        AccessPassConfiguration.Data storage data = AccessPassConfiguration.load();
        assembly {
            s := data.slot
        }
    }

    function set(AccessPassConfiguration.Data memory config) external {
        AccessPassConfiguration.set(config);
    }
}

contract AccessPassConfigurationTest is Test {
    ExposedAccessPassConfiguration internal accessPassConfiguration;

    function setUp() public {
        accessPassConfiguration = new ExposedAccessPassConfiguration();
    }

    function test_Load() public {
        bytes32 slot = accessPassConfiguration.load();

        assertEq(slot, keccak256(abi.encode("xyz.voltz.AccessPassConfiguration")));
    }

    function test_Set() public {
        accessPassConfiguration.set(
            AccessPassConfiguration.Data({
                accessPassNFTAddress: address(1)
            })
        );

        AccessPassConfiguration.Data memory config = accessPassConfiguration.getAccessPassConfiguration();

        assertEq(config.accessPassNFTAddress, address(1));
    }

    function test_Set_Twice() public {
        accessPassConfiguration.set(
            AccessPassConfiguration.Data({
                accessPassNFTAddress: address(1)
            })
        );

        accessPassConfiguration.set(
            AccessPassConfiguration.Data({
                accessPassNFTAddress: address(2)
            })
        );

        AccessPassConfiguration.Data memory config = accessPassConfiguration.getAccessPassConfiguration();

        assertEq(config.accessPassNFTAddress, address(2));
    }
}

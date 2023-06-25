/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/AccessPassConfigurationModule.sol";

contract AccessPassConfigurationModuleTest is Test {
    event AccessPassConfigured(AccessPassConfiguration.Data config, uint256 blockTimestamp);

    AccessPassConfigurationModule internal accessPassConfigurationModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        accessPassConfigurationModule = new AccessPassConfigurationModule();

        vm.store(
            address(accessPassConfigurationModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );
    }

    function test_ConfigureAccessPass() public {
        AccessPassConfiguration.Data memory config = AccessPassConfiguration.Data({
            accessPassNFTAddress: address(1)
        });

        // Expect AccessPassConfigured event
        vm.expectEmit(true, true, true, true, address(accessPassConfigurationModule));
        emit AccessPassConfigured(config, block.timestamp);

        vm.prank(owner);
        accessPassConfigurationModule.configureAccessPass(config);

        AccessPassConfiguration.Data memory existingConfig = accessPassConfigurationModule.getAccessPassConfiguration();

        assertEq(existingConfig.accessPassNFTAddress, config.accessPassNFTAddress);
    }

    function testFuzz_RevertWhen_ConfigureAccessPass_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        AccessPassConfiguration.Data memory config = AccessPassConfiguration.Data({
            accessPassNFTAddress: address(1)
        });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        accessPassConfigurationModule.configureAccessPass(config);
    }

    function test_GetAccessPassConfiguration() public {
        vm.prank(owner);
        accessPassConfigurationModule.configureAccessPass(
            AccessPassConfiguration.Data({
                accessPassNFTAddress: address(1)
            })
        );

        vm.prank(owner);
        accessPassConfigurationModule.configureAccessPass(
            AccessPassConfiguration.Data({
                accessPassNFTAddress: address(1)
            })
        );

        AccessPassConfiguration.Data memory existingConfig = accessPassConfigurationModule.getAccessPassConfiguration();

        assertEq(existingConfig.accessPassNFTAddress, address(1));
    }
}

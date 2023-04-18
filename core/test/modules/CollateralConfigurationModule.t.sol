// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/modules/CollateralConfigurationModule.sol";
import "../test-utils/Constants.sol";

contract CollateralConfigurationModuleTest is Test {
    event CollateralConfigured(address indexed collateralType, CollateralConfiguration.Data config);

    CollateralConfigurationModule internal collateralConfigurationModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        collateralConfigurationModule = new CollateralConfigurationModule();

        vm.store(
            address(collateralConfigurationModule), keccak256(abi.encode("xyz.voltz.OwnableStorage")), bytes32(abi.encode(owner))
        );
    }

    function test_ConfigureCollateral() public {
        CollateralConfiguration.Data memory config =
            CollateralConfiguration.Data({
                depositingEnabled: true, liquidationBooster: 1e18, tokenAddress: Constants.TOKEN_0, cap: Constants.TOKEN_0_CAP
            });

        // Expect CollateralConfigured event
        vm.expectEmit(true, true, true, true, address(collateralConfigurationModule));
        emit CollateralConfigured(Constants.TOKEN_0, config);

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(config);

        CollateralConfiguration.Data memory existingConfig =
            collateralConfigurationModule.getCollateralConfiguration(Constants.TOKEN_0);

        assertEq(existingConfig.depositingEnabled, config.depositingEnabled);
        assertEq(existingConfig.liquidationBooster, config.liquidationBooster);
        assertEq(existingConfig.tokenAddress, config.tokenAddress);
        assertEq(existingConfig.cap, config.cap);
    }

    function testFuzz_RevertWhen_ConfigureCollateral_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        CollateralConfiguration.Data memory config =
            CollateralConfiguration.Data({
                depositingEnabled: true, liquidationBooster: 1e18, tokenAddress: Constants.TOKEN_0, cap: Constants.TOKEN_0_CAP
            });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        collateralConfigurationModule.configureCollateral(config);
    }

    function test_GetCollateralConfiguration() public {
        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({
                depositingEnabled: true, liquidationBooster: 1e18, tokenAddress: Constants.TOKEN_0, cap: Constants.TOKEN_0_CAP
            })
        );

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({
                depositingEnabled: false, liquidationBooster: 1e16, tokenAddress: Constants.TOKEN_1, cap: Constants.TOKEN_1_CAP
            })
        );

        CollateralConfiguration.Data memory existingConfig =
            collateralConfigurationModule.getCollateralConfiguration(Constants.TOKEN_1);

        assertEq(existingConfig.depositingEnabled, false);
        assertEq(existingConfig.liquidationBooster, 1e16);
        assertEq(existingConfig.tokenAddress, Constants.TOKEN_1);
        assertEq(existingConfig.cap, Constants.TOKEN_1_CAP);
    }

    function test_GetCollateralConfiguration_Empty() public {
        CollateralConfiguration.Data memory existingConfig =
            collateralConfigurationModule.getCollateralConfiguration(Constants.TOKEN_1);

        assertEq(existingConfig.depositingEnabled, false);
        assertEq(existingConfig.liquidationBooster, 0);
        assertEq(existingConfig.tokenAddress, address(0));
    }

    function test_GetCollateralConfigurations_All() public {
        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({
                depositingEnabled: true, liquidationBooster: 1e18, tokenAddress: Constants.TOKEN_0, cap: Constants.TOKEN_0_CAP
            })
        );

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({
                depositingEnabled: false, liquidationBooster: 1e16, tokenAddress: Constants.TOKEN_1, cap: Constants.TOKEN_1_CAP
            })
        );

        CollateralConfiguration.Data[] memory configs = collateralConfigurationModule.getCollateralConfigurations(false);

        assertEq(configs.length, 2);

        assertEq(configs[0].depositingEnabled, true);
        assertEq(configs[0].liquidationBooster, 1e18);
        assertEq(configs[0].tokenAddress, Constants.TOKEN_0);
        assertEq(configs[0].cap, Constants.TOKEN_0_CAP);

        assertEq(configs[1].depositingEnabled, false);
        assertEq(configs[1].liquidationBooster, 1e16);
        assertEq(configs[1].tokenAddress, Constants.TOKEN_1);
        assertEq(configs[1].cap, Constants.TOKEN_1_CAP);
    }

    function test_GetCollateralConfigurations_OnlyEnabled() public {
        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({
                depositingEnabled: true, liquidationBooster: 1e18, tokenAddress: Constants.TOKEN_0, cap: Constants.TOKEN_0_CAP
            })
        );

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({
                depositingEnabled: false, liquidationBooster: 1e16, tokenAddress: Constants.TOKEN_1, cap: Constants.TOKEN_1_CAP
            })
        );

        CollateralConfiguration.Data[] memory configs = collateralConfigurationModule.getCollateralConfigurations(true);

        assertEq(configs.length, 1);

        assertEq(configs[0].depositingEnabled, true);
        assertEq(configs[0].liquidationBooster, 1e18);
        assertEq(configs[0].tokenAddress, Constants.TOKEN_0);
        assertEq(configs[0].cap, Constants.TOKEN_0_CAP);
    }
}

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
            CollateralConfiguration.Data({ depositingEnabled: true, liquidationReward: 1e18, tokenAddress: Constants.TOKEN_0 });

        // Expect CollateralConfigured event
        vm.expectEmit(true, true, true, true, address(collateralConfigurationModule));
        emit CollateralConfigured(Constants.TOKEN_0, config);

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(config);

        CollateralConfiguration.Data memory existingConfig =
            collateralConfigurationModule.getCollateralConfiguration(Constants.TOKEN_0);

        assertEq(existingConfig.depositingEnabled, config.depositingEnabled);
        assertEq(existingConfig.liquidationReward, config.liquidationReward);
        assertEq(existingConfig.tokenAddress, config.tokenAddress);
    }

    function testFuzz_revertWhen_ConfigureCollateral_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        CollateralConfiguration.Data memory config =
            CollateralConfiguration.Data({ depositingEnabled: true, liquidationReward: 1e18, tokenAddress: Constants.TOKEN_0 });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        collateralConfigurationModule.configureCollateral(config);
    }

    function test_GetCollateralConfiguration() public {
        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({ depositingEnabled: true, liquidationReward: 1e18, tokenAddress: Constants.TOKEN_0 })
        );

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({ depositingEnabled: false, liquidationReward: 1e16, tokenAddress: Constants.TOKEN_1 })
        );

        CollateralConfiguration.Data memory existingConfig =
            collateralConfigurationModule.getCollateralConfiguration(Constants.TOKEN_1);

        assertEq(existingConfig.depositingEnabled, false);
        assertEq(existingConfig.liquidationReward, 1e16);
        assertEq(existingConfig.tokenAddress, Constants.TOKEN_1);
    }

    function test_GetCollateralConfiguration_Empty() public {
        CollateralConfiguration.Data memory existingConfig =
            collateralConfigurationModule.getCollateralConfiguration(Constants.TOKEN_1);

        assertEq(existingConfig.depositingEnabled, false);
        assertEq(existingConfig.liquidationReward, 0);
        assertEq(existingConfig.tokenAddress, address(0));
    }

    function test_GetCollateralConfigurations_All() public {
        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({ depositingEnabled: true, liquidationReward: 1e18, tokenAddress: Constants.TOKEN_0 })
        );

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({ depositingEnabled: false, liquidationReward: 1e16, tokenAddress: Constants.TOKEN_1 })
        );

        CollateralConfiguration.Data[] memory configs = collateralConfigurationModule.getCollateralConfigurations(false);

        assertEq(configs.length, 2);

        assertEq(configs[0].depositingEnabled, true);
        assertEq(configs[0].liquidationReward, 1e18);
        assertEq(configs[0].tokenAddress, Constants.TOKEN_0);

        assertEq(configs[1].depositingEnabled, false);
        assertEq(configs[1].liquidationReward, 1e16);
        assertEq(configs[1].tokenAddress, Constants.TOKEN_1);
    }

    function test_GetCollateralConfigurations_OnlyEnabled() public {
        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({ depositingEnabled: true, liquidationReward: 1e18, tokenAddress: Constants.TOKEN_0 })
        );

        vm.prank(owner);
        collateralConfigurationModule.configureCollateral(
            CollateralConfiguration.Data({ depositingEnabled: false, liquidationReward: 1e16, tokenAddress: Constants.TOKEN_1 })
        );

        CollateralConfiguration.Data[] memory configs = collateralConfigurationModule.getCollateralConfigurations(true);

        assertEq(configs.length, 1);

        assertEq(configs[0].depositingEnabled, true);
        assertEq(configs[0].liquidationReward, 1e18);
        assertEq(configs[0].tokenAddress, Constants.TOKEN_0);
    }
}

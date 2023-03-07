//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/storage/CollateralConfiguration.sol";
import "../test-utils/Constants.sol";

contract ExposedCollateralConfiguration {
    using SetUtil for SetUtil.AddressSet;

    // Mock support
    function getCollateralConfiguration(address token) external pure returns (CollateralConfiguration.Data memory) {
        return CollateralConfiguration.load(token);
    }

    function getAvailableCollaterals() external view returns (address[] memory) {
        return CollateralConfiguration.loadAvailableCollaterals().values();
    }

    // Exposed functions
    function load(address token) external pure returns (bytes32 s) {
        CollateralConfiguration.Data storage data = CollateralConfiguration.load(token);
        assembly {
            s := data.slot
        }
    }

    function loadAvailableCollaterals() external pure returns (bytes32 s) {
        SetUtil.AddressSet storage data = CollateralConfiguration.loadAvailableCollaterals();
        assembly {
            s := data.slot
        }
    }

    function set(CollateralConfiguration.Data memory config) external {
        CollateralConfiguration.set(config);
    }

    function collateralEnabled(address token) external view {
        CollateralConfiguration.collateralEnabled(token);
    }
}

contract CollateralConfigurationTest is Test {
    ExposedCollateralConfiguration internal collateralConfiguration;

    function setUp() public {
        collateralConfiguration = new ExposedCollateralConfiguration();
    }

    function test_LoadCollateralConfiguration() public {
        bytes32 slot = collateralConfiguration.load(Constants.TOKEN_0);

        assertEq(slot, keccak256(abi.encode("xyz.voltz.CollateralConfiguration", Constants.TOKEN_0)));
    }

    function test_LoadAvailableCollaterals() public {
        bytes32 slot = collateralConfiguration.loadAvailableCollaterals();

        assertEq(slot, keccak256(abi.encode("xyz.voltz.CollateralConfiguration_availableCollaterals")));
    }

    function test_Set() public {
        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationReward: 5e16,
                tokenAddress: Constants.TOKEN_0
            })
        );

        {
            CollateralConfiguration.Data memory configuration =
                collateralConfiguration.getCollateralConfiguration(Constants.TOKEN_0);

            assertEq(configuration.depositingEnabled, true);
            assertEq(configuration.liquidationReward, 5e16);
            assertEq(configuration.tokenAddress, Constants.TOKEN_0);
        }

        {
            address[] memory availableCollaterals = collateralConfiguration.getAvailableCollaterals();

            assertEq(availableCollaterals.length, 1);
            assertEq(availableCollaterals[0], Constants.TOKEN_0);
        }
    }

    function test_Set_Twice() public {
        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationReward: 5e16,
                tokenAddress: Constants.TOKEN_0
            })
        );

        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationReward: 1e16,
                tokenAddress: Constants.TOKEN_0
            })
        );

        {
            CollateralConfiguration.Data memory configuration =
                collateralConfiguration.getCollateralConfiguration(Constants.TOKEN_0);

            assertEq(configuration.depositingEnabled, true);
            assertEq(configuration.liquidationReward, 1e16);
            assertEq(configuration.tokenAddress, Constants.TOKEN_0);
        }

        {
            address[] memory availableCollaterals = collateralConfiguration.getAvailableCollaterals();

            assertEq(availableCollaterals.length, 1);
            assertEq(availableCollaterals[0], Constants.TOKEN_0);
        }
    }

    function test_Set_MoreConfigurations() public {
        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationReward: 5e16,
                tokenAddress: Constants.TOKEN_0
            })
        );

        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: false,
                liquidationReward: 1e16,
                tokenAddress: Constants.TOKEN_1
            })
        );

        {
            CollateralConfiguration.Data memory configuration =
                collateralConfiguration.getCollateralConfiguration(Constants.TOKEN_0);

            assertEq(configuration.depositingEnabled, true);
            assertEq(configuration.liquidationReward, 5e16);
            assertEq(configuration.tokenAddress, Constants.TOKEN_0);
        }

        {
            CollateralConfiguration.Data memory configuration =
                collateralConfiguration.getCollateralConfiguration(Constants.TOKEN_1);

            assertEq(configuration.depositingEnabled, false);
            assertEq(configuration.liquidationReward, 1e16);
            assertEq(configuration.tokenAddress, Constants.TOKEN_1);
        }

        {
            address[] memory availableCollaterals = collateralConfiguration.getAvailableCollaterals();

            assertEq(availableCollaterals.length, 2);
            assertEq(availableCollaterals[0], Constants.TOKEN_0);
            assertEq(availableCollaterals[1], Constants.TOKEN_1);
        }
    }

    function test_CollateralEnabled() public {
        {
            vm.expectRevert(
                abi.encodeWithSelector(CollateralConfiguration.CollateralDepositDisabled.selector, Constants.TOKEN_0)
            );
            collateralConfiguration.collateralEnabled(Constants.TOKEN_0);

            vm.expectRevert(
                abi.encodeWithSelector(CollateralConfiguration.CollateralDepositDisabled.selector, Constants.TOKEN_1)
            );
            collateralConfiguration.collateralEnabled(Constants.TOKEN_1);
        }

        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationReward: 5e16,
                tokenAddress: Constants.TOKEN_0
            })
        );

        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: false,
                liquidationReward: 1e16,
                tokenAddress: Constants.TOKEN_1
            })
        );

        {
            collateralConfiguration.collateralEnabled(Constants.TOKEN_0);

            vm.expectRevert(
                abi.encodeWithSelector(CollateralConfiguration.CollateralDepositDisabled.selector, Constants.TOKEN_1)
            );
            collateralConfiguration.collateralEnabled(Constants.TOKEN_1);
        }

        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: false,
                liquidationReward: 5e16,
                tokenAddress: Constants.TOKEN_0
            })
        );

        collateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationReward: 1e16,
                tokenAddress: Constants.TOKEN_1
            })
        );

        {
            vm.expectRevert(
                abi.encodeWithSelector(CollateralConfiguration.CollateralDepositDisabled.selector, Constants.TOKEN_0)
            );
            collateralConfiguration.collateralEnabled(Constants.TOKEN_0);

            collateralConfiguration.collateralEnabled(Constants.TOKEN_1);
        }
    }
}

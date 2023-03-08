// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/modules/RiskConfigurationModule.sol";
import "../test-utils/Constants.sol";

contract RiskConfigurationModuleTest is Test {
    event MarketRiskConfigured(MarketRiskConfiguration.Data config);
    event ProtocolRiskConfigured(ProtocolRiskConfiguration.Data config);

    RiskConfigurationModule internal riskConfigurationModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        riskConfigurationModule = new RiskConfigurationModule();

        vm.store(address(riskConfigurationModule), keccak256(abi.encode("xyz.voltz.OwnableStorage")), bytes32(abi.encode(owner)));
    }

    function test_ConfigureMarketRisk() public {
        MarketRiskConfiguration.Data memory config =
            MarketRiskConfiguration.Data({ productId: 1, marketId: 10, riskParameter: 1e16 });

        // Expect MarketRiskConfigured event
        vm.expectEmit(true, true, true, true, address(riskConfigurationModule));
        emit MarketRiskConfigured(config);

        vm.prank(owner);
        riskConfigurationModule.configureMarketRisk(config);

        MarketRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getMarketRiskConfiguration(1, 10);

        assertEq(existingConfig.productId, config.productId);
        assertEq(existingConfig.marketId, config.marketId);
        assertEq(existingConfig.riskParameter, config.riskParameter);
    }

    function testFuzz_revertWhen_ConfigureMarketRisk_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        MarketRiskConfiguration.Data memory config =
            MarketRiskConfiguration.Data({ productId: 1, marketId: 10, riskParameter: 1e16 });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        riskConfigurationModule.configureMarketRisk(config);
    }

    function test_GetMarketRiskConfiguration() public {
        vm.prank(owner);
        riskConfigurationModule.configureMarketRisk(
            MarketRiskConfiguration.Data({ productId: 1, marketId: 10, riskParameter: 1e16 })
        );

        vm.prank(owner);
        riskConfigurationModule.configureMarketRisk(
            MarketRiskConfiguration.Data({ productId: 2, marketId: 20, riskParameter: 2e16 })
        );

        MarketRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getMarketRiskConfiguration(2, 20);

        assertEq(existingConfig.productId, 2);
        assertEq(existingConfig.marketId, 20);
        assertEq(existingConfig.riskParameter, 2e16);
    }

    function test_GetMarketRiskConfiguration_Empty() public {
        MarketRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getMarketRiskConfiguration(2, 20);

        assertEq(existingConfig.productId, 0);
        assertEq(existingConfig.marketId, 0);
        assertEq(existingConfig.riskParameter, 0);
    }

    function test_ConfigureProtocolRisk() public {
        ProtocolRiskConfiguration.Data memory config =
            ProtocolRiskConfiguration.Data({ imMultiplier: 2e18, liquidatorRewardParameter: 5e16 });

        // Expect ProtocolRiskConfigured event
        vm.expectEmit(true, true, true, true, address(riskConfigurationModule));
        emit ProtocolRiskConfigured(config);

        vm.prank(owner);
        riskConfigurationModule.configureProtocolRisk(config);

        ProtocolRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getProtocolRiskConfiguration();

        assertEq(existingConfig.imMultiplier, config.imMultiplier);
        assertEq(existingConfig.liquidatorRewardParameter, config.liquidatorRewardParameter);
    }

    function testFuzz_revertWhen_ConfigureProtocolRisk_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        ProtocolRiskConfiguration.Data memory config =
            ProtocolRiskConfiguration.Data({ imMultiplier: 2e18, liquidatorRewardParameter: 5e16 });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        riskConfigurationModule.configureProtocolRisk(config);
    }

    function test_GetProtocolRiskConfiguration() public {
        vm.prank(owner);
        riskConfigurationModule.configureProtocolRisk(
            ProtocolRiskConfiguration.Data({ imMultiplier: 2e18, liquidatorRewardParameter: 5e16 })
        );

        vm.prank(owner);
        riskConfigurationModule.configureProtocolRisk(
            ProtocolRiskConfiguration.Data({ imMultiplier: 4e18, liquidatorRewardParameter: 10e16 })
        );

        ProtocolRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getProtocolRiskConfiguration();

        assertEq(existingConfig.imMultiplier, 4e18);
        assertEq(existingConfig.liquidatorRewardParameter, 10e16);
    }
}

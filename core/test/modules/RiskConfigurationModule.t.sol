/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/RiskConfigurationModule.sol";
import "../test-utils/Constants.sol";

import {UD60x18} from "@prb/math/UD60x18.sol";

contract RiskConfigurationModuleTest is Test {
    event MarketRiskConfigured(MarketRiskConfiguration.Data config, uint256 blockTimestamp);
    event ProtocolRiskConfigured(ProtocolRiskConfiguration.Data config, uint256 blockTimestamp);

    RiskConfigurationModule internal riskConfigurationModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        riskConfigurationModule = new RiskConfigurationModule();

        vm.store(
            address(riskConfigurationModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );
    }

    function test_ConfigureMarketRisk() public {
        MarketRiskConfiguration.Data memory config =
            MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: UD60x18.wrap(1e16), twapLookbackWindow: 86400});

        // Expect MarketRiskConfigured event
        vm.expectEmit(true, true, true, true, address(riskConfigurationModule));
        emit MarketRiskConfigured(config, block.timestamp);

        vm.prank(owner);
        riskConfigurationModule.configureMarketRisk(config);

        MarketRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getMarketRiskConfiguration(1, 10);

        assertEq(existingConfig.productId, config.productId);
        assertEq(existingConfig.marketId, config.marketId);
        assertEq(UD60x18.unwrap(existingConfig.riskParameter), UD60x18.unwrap(config.riskParameter));
    }

    function testFuzz_RevertWhen_ConfigureMarketRisk_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        MarketRiskConfiguration.Data memory config =
            MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: UD60x18.wrap(1e16), twapLookbackWindow: 86400});

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        riskConfigurationModule.configureMarketRisk(config);
    }

    function test_GetMarketRiskConfiguration() public {
        vm.prank(owner);
        riskConfigurationModule.configureMarketRisk(
            MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: UD60x18.wrap(1e16), twapLookbackWindow: 86400})
        );

        vm.prank(owner);
        riskConfigurationModule.configureMarketRisk(
            MarketRiskConfiguration.Data({productId: 2, marketId: 20, riskParameter: UD60x18.wrap(2e16), twapLookbackWindow: 86400})
        );

        MarketRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getMarketRiskConfiguration(2, 20);

        assertEq(existingConfig.productId, 2);
        assertEq(existingConfig.marketId, 20);
        assertEq(UD60x18.unwrap(existingConfig.riskParameter), 2e16);
    }

    function test_GetMarketRiskConfiguration_Empty() public {
        MarketRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getMarketRiskConfiguration(2, 20);

        assertEq(existingConfig.productId, 0);
        assertEq(existingConfig.marketId, 0);
        assertEq(UD60x18.unwrap(existingConfig.riskParameter), 0);
    }

    function test_ConfigureProtocolRisk() public {
        ProtocolRiskConfiguration.Data memory config = ProtocolRiskConfiguration.Data({
            imMultiplier: UD60x18.wrap(2e18),
            liquidatorRewardParameter: UD60x18.wrap(5e16)
        });

        // Expect ProtocolRiskConfigured event
        vm.expectEmit(true, true, true, true, address(riskConfigurationModule));
        emit ProtocolRiskConfigured(config, block.timestamp);

        vm.prank(owner);
        riskConfigurationModule.configureProtocolRisk(config);

        ProtocolRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getProtocolRiskConfiguration();

        assertEq(UD60x18.unwrap(existingConfig.imMultiplier), UD60x18.unwrap(config.imMultiplier));
        assertEq(
            UD60x18.unwrap(existingConfig.liquidatorRewardParameter), UD60x18.unwrap(config.liquidatorRewardParameter)
        );
    }

    function testFuzz_RevertWhen_ConfigureProtocolRisk_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        ProtocolRiskConfiguration.Data memory config = ProtocolRiskConfiguration.Data({
            imMultiplier: UD60x18.wrap(2e18),
            liquidatorRewardParameter: UD60x18.wrap(5e16)
        });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        riskConfigurationModule.configureProtocolRisk(config);
    }

    function test_GetProtocolRiskConfiguration() public {
        vm.prank(owner);
        riskConfigurationModule.configureProtocolRisk(
            ProtocolRiskConfiguration.Data({
                imMultiplier: UD60x18.wrap(2e18),
                liquidatorRewardParameter: UD60x18.wrap(5e16)
            })
        );

        vm.prank(owner);
        riskConfigurationModule.configureProtocolRisk(
            ProtocolRiskConfiguration.Data({
                imMultiplier: UD60x18.wrap(4e18),
                liquidatorRewardParameter: UD60x18.wrap(10e16)
            })
        );

        ProtocolRiskConfiguration.Data memory existingConfig = riskConfigurationModule.getProtocolRiskConfiguration();

        assertEq(UD60x18.unwrap(existingConfig.imMultiplier), 4e18);
        assertEq(UD60x18.unwrap(existingConfig.liquidatorRewardParameter), 10e16);
    }
}

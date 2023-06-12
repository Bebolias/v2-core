/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/FeeConfigurationModule.sol";
import "../test-utils/Constants.sol";

import {UD60x18} from "@prb/math/UD60x18.sol";

contract ExposedFeeConfigurationModule is FeeConfigurationModule {
    constructor() {
        Account.create(13, address(1));
    }
}

contract FeeConfigurationModuleTest is Test {
    event MarketFeeConfigured(MarketFeeConfiguration.Data config, uint256 blockTimestamp);

    ExposedFeeConfigurationModule internal feeConfigurationModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        feeConfigurationModule = new ExposedFeeConfigurationModule();

        vm.store(
            address(feeConfigurationModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );
    }

    function test_ConfigureMarketFee() public {
        MarketFeeConfiguration.Data memory config = MarketFeeConfiguration.Data({
            productId: 1,
            marketId: 10,
            feeCollectorAccountId: 13,
            atomicMakerFee: UD60x18.wrap(1e15),
            atomicTakerFee: UD60x18.wrap(2e15)
        });

        // Expect MarketFeeConfigured event
        vm.expectEmit(true, true, true, true, address(feeConfigurationModule));
        emit MarketFeeConfigured(config, block.timestamp);

        vm.prank(owner);
        feeConfigurationModule.configureMarketFee(config);

        MarketFeeConfiguration.Data memory existingConfig = feeConfigurationModule.getMarketFeeConfiguration(1, 10);

        assertEq(existingConfig.productId, config.productId);
        assertEq(existingConfig.marketId, config.marketId);
        assertEq(existingConfig.feeCollectorAccountId, config.feeCollectorAccountId);
        assertEq(UD60x18.unwrap(existingConfig.atomicMakerFee), UD60x18.unwrap(config.atomicMakerFee));
        assertEq(UD60x18.unwrap(existingConfig.atomicTakerFee), UD60x18.unwrap(config.atomicTakerFee));
    }

    function testFuzz_RevertWhen_ConfigureMarketFee_NoOwner(address otherAddress) public {
        vm.assume(otherAddress != owner);

        MarketFeeConfiguration.Data memory config = MarketFeeConfiguration.Data({
            productId: 1,
            marketId: 10,
            feeCollectorAccountId: 13,
            atomicMakerFee: UD60x18.wrap(1e15),
            atomicTakerFee: UD60x18.wrap(2e15)
        });

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        vm.prank(otherAddress);
        feeConfigurationModule.configureMarketFee(config);
    }

    function test_GetMarketFeeConfiguration() public {
        vm.prank(owner);
        feeConfigurationModule.configureMarketFee(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 10,
                feeCollectorAccountId: 13,
                atomicMakerFee: UD60x18.wrap(1e15),
                atomicTakerFee: UD60x18.wrap(2e15)
            })
        );

        vm.prank(owner);
        feeConfigurationModule.configureMarketFee(
            MarketFeeConfiguration.Data({
                productId: 2,
                marketId: 20,
                feeCollectorAccountId: 13,
                atomicMakerFee: UD60x18.wrap(2e15),
                atomicTakerFee: UD60x18.wrap(1e15)
            })
        );

        MarketFeeConfiguration.Data memory existingConfig = feeConfigurationModule.getMarketFeeConfiguration(2, 20);

        assertEq(existingConfig.productId, 2);
        assertEq(existingConfig.marketId, 20);
        assertEq(existingConfig.feeCollectorAccountId, 13);
        assertEq(UD60x18.unwrap(existingConfig.atomicMakerFee), 2e15);
        assertEq(UD60x18.unwrap(existingConfig.atomicTakerFee), 1e15);
    }

    function test_GetMarketFeeConfiguration_Empty() public {
        MarketFeeConfiguration.Data memory existingConfig = feeConfigurationModule.getMarketFeeConfiguration(2, 20);

        assertEq(existingConfig.productId, 0);
        assertEq(existingConfig.marketId, 0);
        assertEq(UD60x18.unwrap(existingConfig.atomicMakerFee), 0);
        assertEq(UD60x18.unwrap(existingConfig.atomicTakerFee), 0);
    }

    // todo: test fee collector account does not exist
}

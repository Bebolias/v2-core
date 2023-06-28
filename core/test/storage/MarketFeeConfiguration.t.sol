/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/MarketFeeConfiguration.sol";

import {UD60x18} from "@prb/math/UD60x18.sol";

contract ExposedMarketFeeConfiguration {
    constructor() {
        Account.create(13, address(1));
        Account.create(15, address(1));
    }
    // Mock support

    function getMarketFeeConfiguration(uint128 productId, uint128 marketId)
        external
        pure
        returns (MarketFeeConfiguration.Data memory)
    {
        return MarketFeeConfiguration.load(productId, marketId);
    }

    // Exposed functions
    function load(uint128 productId, uint128 marketId) external pure returns (bytes32 s) {
        MarketFeeConfiguration.Data storage data = MarketFeeConfiguration.load(productId, marketId);
        assembly {
            s := data.slot
        }
    }

    function set(MarketFeeConfiguration.Data memory config) external {
        MarketFeeConfiguration.set(config);
    }
}

contract MarketFeeConfigurationTest is Test {
    ExposedMarketFeeConfiguration internal marketFeeConfiguration;

    function setUp() public {
        marketFeeConfiguration = new ExposedMarketFeeConfiguration();
    }

    function test_Load() public {
        bytes32 s = keccak256(abi.encode("xyz.voltz.MarketFeeConfiguration", 1, 10));
        assertEq(marketFeeConfiguration.load(1, 10), s);
    }

    function test_Set() public {
        marketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 10,
                feeCollectorAccountId: 13,
                atomicMakerFee: UD60x18.wrap(1e15),
                atomicTakerFee: UD60x18.wrap(2e15)
            })
        );

        MarketFeeConfiguration.Data memory data = marketFeeConfiguration.getMarketFeeConfiguration(1, 10);

        assertEq(data.productId, 1);
        assertEq(data.marketId, 10);
        assertEq(data.feeCollectorAccountId, 13);
        assertEq(UD60x18.unwrap(data.atomicMakerFee), 1e15);
        assertEq(UD60x18.unwrap(data.atomicTakerFee), 2e15);
    }

    function test_Set_Twice() public {
        marketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 10,
                feeCollectorAccountId: 13,
                atomicMakerFee: UD60x18.wrap(1e15),
                atomicTakerFee: UD60x18.wrap(2e15)
            })
        );

        marketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 10,
                feeCollectorAccountId: 15,
                atomicMakerFee: UD60x18.wrap(3e15),
                atomicTakerFee: UD60x18.wrap(4e15)
            })
        );

        MarketFeeConfiguration.Data memory data = marketFeeConfiguration.getMarketFeeConfiguration(1, 10);

        assertEq(data.productId, 1);
        assertEq(data.marketId, 10);
        assertEq(data.feeCollectorAccountId, 15);
        assertEq(UD60x18.unwrap(data.atomicMakerFee), 3e15);
        assertEq(UD60x18.unwrap(data.atomicTakerFee), 4e15);
    }

    function test_Set_MoreConfigurations() public {
        marketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 10,
                feeCollectorAccountId: 13,
                atomicMakerFee: UD60x18.wrap(1e15),
                atomicTakerFee: UD60x18.wrap(2e15)
            })
        );

        marketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 2,
                marketId: 20,
                feeCollectorAccountId: 15,
                atomicMakerFee: UD60x18.wrap(2e15),
                atomicTakerFee: UD60x18.wrap(1e15)
            })
        );

        {
            MarketFeeConfiguration.Data memory data = marketFeeConfiguration.getMarketFeeConfiguration(1, 10);

            assertEq(data.productId, 1);
            assertEq(data.marketId, 10);
            assertEq(data.feeCollectorAccountId, 13);
            assertEq(UD60x18.unwrap(data.atomicMakerFee), 1e15);
            assertEq(UD60x18.unwrap(data.atomicTakerFee), 2e15);
        }

        {
            MarketFeeConfiguration.Data memory data = marketFeeConfiguration.getMarketFeeConfiguration(2, 20);

            assertEq(data.productId, 2);
            assertEq(data.marketId, 20);
            assertEq(data.feeCollectorAccountId, 15);
            assertEq(UD60x18.unwrap(data.atomicMakerFee), 2e15);
            assertEq(UD60x18.unwrap(data.atomicTakerFee), 1e15);
        }
    }

    // todo: test fee collector account does not exist (AN)
}

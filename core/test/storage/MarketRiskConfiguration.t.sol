//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/storage/MarketRiskConfiguration.sol";

contract ExposedMarketRiskConfiguration {
    // Mock support
    function getMarketRiskConfiguration(
        uint128 productId,
        uint128 marketId
    )
        external
        pure
        returns (MarketRiskConfiguration.Data memory)
    {
        return MarketRiskConfiguration.load(productId, marketId);
    }

    // Exposed functions
    function load(uint128 productId, uint128 marketId) external pure returns (bytes32 s) {
        MarketRiskConfiguration.Data storage data = MarketRiskConfiguration.load(productId, marketId);
        assembly {
            s := data.slot
        }
    }

    function set(MarketRiskConfiguration.Data memory config) external {
        MarketRiskConfiguration.set(config);
    }
}

contract MarketRiskConfigurationTest is Test {
    ExposedMarketRiskConfiguration internal marketRiskConfiguration;

    function setUp() public {
        marketRiskConfiguration = new ExposedMarketRiskConfiguration();
    }

    function test_Load() public {
        bytes32 s = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 1, 10));
        assertEq(marketRiskConfiguration.load(1, 10), s);
    }

    function test_Set() public {
        marketRiskConfiguration.set(MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: 1e18}));

        MarketRiskConfiguration.Data memory data = marketRiskConfiguration.getMarketRiskConfiguration(1, 10);

        assertEq(data.productId, 1);
        assertEq(data.marketId, 10);
        assertEq(data.riskParameter, 1e18);
    }

    function test_Set_Twice() public {
        marketRiskConfiguration.set(MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: 1e18}));

        marketRiskConfiguration.set(MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: 2e18}));

        MarketRiskConfiguration.Data memory data = marketRiskConfiguration.getMarketRiskConfiguration(1, 10);

        assertEq(data.productId, 1);
        assertEq(data.marketId, 10);
        assertEq(data.riskParameter, 2e18);
    }

    function test_Set_MoreConfigurations() public {
        marketRiskConfiguration.set(MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: 1e18}));

        marketRiskConfiguration.set(MarketRiskConfiguration.Data({productId: 2, marketId: 20, riskParameter: 2e18}));

        {
            MarketRiskConfiguration.Data memory data = marketRiskConfiguration.getMarketRiskConfiguration(1, 10);

            assertEq(data.productId, 1);
            assertEq(data.marketId, 10);
            assertEq(data.riskParameter, 1e18);
        }

        {
            MarketRiskConfiguration.Data memory data = marketRiskConfiguration.getMarketRiskConfiguration(2, 20);

            assertEq(data.productId, 2);
            assertEq(data.marketId, 20);
            assertEq(data.riskParameter, 2e18);
        }
    }
}

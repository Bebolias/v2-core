/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/ProductConfiguration.sol";

contract ExposeProductConfiguration {
    using ProductConfiguration for ProductConfiguration.Data;

    // Exposed functions
    function load() external pure returns (bytes32 s) {
        ProductConfiguration.Data storage product = ProductConfiguration.load();
        assembly {
            s := product.slot
        }
    }

    function getCoreProxyAddress() external view returns (address) {
        return ProductConfiguration.getCoreProxyAddress();
    }

    function getPoolAddress() external view returns (address) {
        return ProductConfiguration.getPoolAddress();
    }

    function getProductId() external view returns (uint128) {
        return ProductConfiguration.getProductId();
    }

    function set(ProductConfiguration.Data memory data) external {
        ProductConfiguration.set(data);
    }
}

contract ProductConfigurationTest is Test {
    using ProductConfiguration for ProductConfiguration.Data;

    ExposeProductConfiguration productConfiguration;

    address constant MOCK_POOL_ADDRESS = address(1);
    address constant MOCK_PROXY_ADDRESS = address(2);
    uint128 constant MOCK_PRODUCT_ID = 100;

    function setUp() public virtual {
        productConfiguration = new ExposeProductConfiguration();
        productConfiguration.set(
            ProductConfiguration.Data({ productId: MOCK_PRODUCT_ID, coreProxy: MOCK_PROXY_ADDRESS, poolAddress: MOCK_POOL_ADDRESS })
        );
    }

    function test_LoadAtCorrectStorageSlot() public {
        bytes32 slot = productConfiguration.load();
        assertEq(slot, keccak256(abi.encode("xyz.voltz.ProductConfiguration")));
    }

    function test_CreatedCorrectly() public {
        assertEq(productConfiguration.getProductId(), MOCK_PRODUCT_ID);
        assertEq(productConfiguration.getCoreProxyAddress(), MOCK_PROXY_ADDRESS);
        assertEq(productConfiguration.getPoolAddress(), MOCK_POOL_ADDRESS);
    }

    function test_SetNewConfigForOldProduct() public {
        productConfiguration.set(ProductConfiguration.Data({ productId: 677, coreProxy: address(3), poolAddress: address(4) }));

        assertEq(productConfiguration.getProductId(), 677);
        assertEq(productConfiguration.getCoreProxyAddress(), address(3));
        assertEq(productConfiguration.getPoolAddress(), address(4));
    }
}

/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/Product.sol";
import "../test-utils/MockCoreStorage.sol";

contract ExposedProduct is CoreState {
    using Product for Product.Data;

    // Exposed functions
    function load(uint128 id) external pure returns (bytes32 s) {
        Product.Data storage product = Product.load(id);
        assembly {
            s := product.slot
        }
    }

    function getProductData(uint128 id) external pure returns (Product.Data memory) {
        Product.Data memory product = Product.load(id);
        return product;
    }

    function onlyProductAddress(uint128 productId, address caller) external view {
        Product.onlyProductAddress(productId, caller);
    }

    function baseToAnnualizedExposure(
        uint128 productId,
        int256[] memory baseAmounts,
        uint128 marketId,
        uint32 maturityTimestamp
    ) external view returns (int256[] memory) {
        Product.Data storage product = Product.load(productId);
        return product.baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp);
    }

    function getAccountTakerAndMakerExposures(uint128 productId, uint128 accountId, address collateralType)
        external
    returns (
        Account.Exposure[] memory takerExposures,
        Account.Exposure[] memory makerExposuresLower,
        Account.Exposure[] memory makerExposuresUpper
    )
    {
        Product.Data storage product = Product.load(productId);
        return product.getAccountTakerAndMakerExposures(accountId, collateralType);
    }

    function closeAccount(uint128 productId, uint128 accountId, address collateralType) external {
        Product.Data storage product = Product.load(productId);
        product.closeAccount(accountId, collateralType);
    }
}

contract ProductTest is Test {
    ExposedProduct internal product;

    uint128 internal productId = 1;
    uint128 internal accountId = 100;

    function setUp() public {
        product = new ExposedProduct();
    }

    function test_Load() public {
        bytes32 slot = product.load(productId);

        assertEq(slot, keccak256(abi.encode("xyz.voltz.Product", productId)));
    }

    function testFuzz_OnlyProductAddress(address otherAddress) public {
        address productAddress = product.getProductData(productId).productAddress;

        vm.assume(otherAddress != productAddress);

        product.onlyProductAddress(productId, productAddress);

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        product.onlyProductAddress(productId, otherAddress);
    }

    function test_BaseToAnnualizedExposure() public {
        int256[] memory baseAmounts = new int256[](1);
        baseAmounts[0] = 100;

        int256[] memory exposures = product.baseToAnnualizedExposure(productId, baseAmounts, 10, 123000);
        assertEq(exposures.length, 1);
        assertEq(exposures[0], 50);

        baseAmounts[0] = 1000;
        exposures = product.baseToAnnualizedExposure(productId, baseAmounts, 11, 120000);
        assertEq(exposures.length, 1);
        assertEq(exposures[0], 250);
    }

    function test_GetAccountTakerAndMakerExposures() public {
        // todo: implementation
    }

    function test_CloseAccount() public {
        product.closeAccount(productId, accountId, Constants.TOKEN_0);
    }

    function test_RevertWhen_CloseAccount_NoProduct() public {
        vm.expectRevert();
        product.closeAccount(0, accountId, Constants.TOKEN_0);
    }
}

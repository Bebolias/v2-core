// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/storage/Product.sol";
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

    function onlyProductOwner(uint128 productId, address caller) external view {
        Product.onlyProductOwner(productId, caller);
    }

    function getAccountUnrealizedPnL(uint128 productId, uint128 accountId) external view returns (int256 accountUnrealizedPnL) {
        Product.Data storage product = Product.load(productId);
        return product.getAccountUnrealizedPnL(accountId);
    }

    function getAccountAnnualizedExposures(
        uint128 productId,
        uint128 accountId
    )
        external
        returns (Account.Exposure[] memory exposures)
    {
        Product.Data storage product = Product.load(productId);
        return product.getAccountAnnualizedExposures(accountId);
    }

    function closeAccount(uint128 productId, uint128 accountId) external {
        Product.Data storage product = Product.load(productId);
        product.closeAccount(accountId);
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

    function testFuzz_OnlyProductOwner(address otherAddress) public {
        vm.assume(otherAddress != Constants.PRODUCT_OWNER);

        product.onlyProductOwner(productId, Constants.PRODUCT_OWNER);

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, otherAddress));
        product.onlyProductOwner(productId, otherAddress);
    }

    function test_GetAccountUnrealizedPnL() public {
        assertEq(product.getAccountUnrealizedPnL(productId, accountId), 100e18);
    }

    function test_GetAnnualizedProductExposures() public {
        Account.Exposure[] memory exposures = product.getAccountAnnualizedExposures(productId, accountId);

        assertEq(exposures.length, 2);

        assertEq(exposures[0].marketId, 10);
        assertEq(exposures[0].filled, 100e18);
        assertEq(exposures[0].unfilledLong, 200e18);
        assertEq(exposures[0].unfilledShort, -200e18);

        assertEq(exposures[1].marketId, 11);
        assertEq(exposures[1].filled, 200e18);
        assertEq(exposures[1].unfilledLong, 300e18);
        assertEq(exposures[1].unfilledShort, -400e18);
    }

    function test_CloseAccount() public {
        product.closeAccount(productId, accountId);
    }

    function test_RevertWhen_CloseAccount_NoProduct() public {
        vm.expectRevert();
        product.closeAccount(0, accountId);
    }
}

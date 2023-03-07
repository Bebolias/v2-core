// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/storage/ProductCreator.sol";

contract ExposedProductCreator {
    // Mock support
    function getLastCreatedProductId() external view returns (uint128) {
        return ProductCreator.getProductStore().lastCreatedProductId;
    }

    function getIdsByAddress(address productAddress) external view returns (uint128[] memory) {
        return ProductCreator.loadIdsByAddress(productAddress);
    }

    function getProduct(uint128 id) external pure returns (Product.Data memory product) {
        product = Product.load(id);
    }

    // Exposed functions
    function getProductStore() external pure returns (bytes32 s) {
        ProductCreator.Data storage productStore = ProductCreator.getProductStore();
        assembly {
            s := productStore.slot
        }
    }

    function create(address productAddress, string memory name, address owner) external returns (bytes32 s) {
        Product.Data storage product = ProductCreator.create(productAddress, name, owner);
        assembly {
            s := product.slot
        }
    }

    function loadIdsByAddress(address productAddress) external view returns (bytes32 s) {
        uint128[] storage ids = ProductCreator.loadIdsByAddress(productAddress);
        assembly {
            s := ids.slot
        }
    }
}

contract ProductCreatorTest is Test {
    ExposedProductCreator internal productCreator;

    function setUp() public {
        productCreator = new ExposedProductCreator();
    }

    function test_GetProductStore() public {
        bytes32 slot = productCreator.getProductStore();

        assertEq(slot, keccak256(abi.encode("xyz.voltz.Products")));
    }

    function test_Create() public {
        address productAddress = vm.addr(1);
        string memory productName = "Product";
        address owner = vm.addr(2);

        bytes32 productSlot = productCreator.create(productAddress, productName, owner);

        assertEq(productSlot, keccak256(abi.encode("xyz.voltz.Product", 1)));

        assertEq(productCreator.getLastCreatedProductId(), 1);

        {
            uint128[] memory idsByAddress = productCreator.getIdsByAddress(productAddress);

            assertEq(idsByAddress.length, 1);
            assertEq(idsByAddress[0], 1);
        }

        {
            Product.Data memory product = productCreator.getProduct(1);

            assertEq(product.id, 1);
            assertEq(product.productAddress, productAddress);
            assertEq(product.name, productName);
            assertEq(product.owner, owner);
        }
    }

    function test_Create_Twice() public {
        address productAddress = vm.addr(1);
        string memory productName = "Product";
        address owner = vm.addr(2);

        {
            bytes32 productSlot = productCreator.create(productAddress, productName, owner);

            assertEq(productSlot, keccak256(abi.encode("xyz.voltz.Product", 1)));
        }

        {
            bytes32 productSlot = productCreator.create(productAddress, productName, owner);

            assertEq(productSlot, keccak256(abi.encode("xyz.voltz.Product", 2)));
        }

        assertEq(productCreator.getLastCreatedProductId(), 2);
    }

    function test_LoadIdsByAddress() public {
        address productAddress = vm.addr(1);
        string memory productName = "Product";
        address owner = vm.addr(2);

        productCreator.create(productAddress, productName, owner);
        productCreator.create(productAddress, productName, owner);

        {
            uint128[] memory idsByAddress = productCreator.getIdsByAddress(productAddress);

            assertEq(idsByAddress.length, 2);
            assertEq(idsByAddress[0], 1);
            assertEq(idsByAddress[1], 2);
        }
    }
}

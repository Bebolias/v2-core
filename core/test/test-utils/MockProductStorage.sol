pragma solidity >=0.8.19;

import "../../src/storage/ProductCreator.sol";

/**
 * @title Object for mocking product storage
 */
contract MockProductStorage {
    using Product for Product.Data;

    function mockProduct(address productAddress, string memory name, address owner) public returns (uint128) {
        Product.Data storage product = ProductCreator.create(productAddress, name, owner);
        return product.id;
    }

    function getProduct(uint128 id) external pure returns (Product.Data memory product) {
        product = Product.load(id);
    }
}

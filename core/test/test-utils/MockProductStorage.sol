/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
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

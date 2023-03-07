// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Enables the owner of the ProductProxy to configure the pool address the product is linked to
 */
library PoolConfiguration {
    bytes32 private constant _SLOT_POOL_CONFIGURATION = keccak256(abi.encode("xyz.voltz.PoolConfigurationr"));

    struct Data {
        /**
         * @dev The Pool Address
         */
        address poolAddress;
    }

    /**
     * @dev Loads the singleton storage info about the pool connected to this product
     */
    function load() internal pure returns (Data storage pool) {
        bytes32 s = _SLOT_POOL_CONFIGURATION;
        assembly {
            pool.slot := s
        }
    }

    /**
     * @dev Sets the pool connected to the product
     * @param config The PoolConfiguration object
     */
    function set(Data memory config) internal {
        Data storage storedConfig = load();

        storedConfig.poolAddress = config.poolAddress;
    }

    /**
     * @dev Gets the address of the pool connected to the dated irs product
     * @return storedPoolAddress Address of the connected pool (e.g. irs vamm pool proxy)
     */
    function getPoolAddress() internal view returns (address storedPoolAddress) {
        Data storage storedConfig = load();
        storedPoolAddress = storedConfig.poolAddress;
    }
}

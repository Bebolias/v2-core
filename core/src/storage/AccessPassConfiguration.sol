/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;


/**
 * @title Tracks V2 Access Pass NFT and providers helpers to interact with it
 */
library AccessPassConfiguration {

    struct Data {
        address accessPassNFTAddress;
    }

    /**
     * @dev Loads the AccessPassConfiguration object.
     * @return config The AccessPassConfiguration object.
     */
    function load() internal pure returns (Data storage config) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.AccessPassConfiguration"));
        assembly {
            config.slot := s
        }
    }

     /**
     * @dev Sets the access pass configuration
     * @param config The AccessPassConfiguration object with access pass nft address
     */
    function set(Data memory config) internal {
        Data storage storedConfig = load();
        storedConfig.accessPassNFTAddress = config.accessPassNFTAddress;
    }

}
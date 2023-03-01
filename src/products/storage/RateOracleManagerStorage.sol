// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
/**
 * @title Represents a Rate Oracle Manager
 * note, this is stored in the DatedIRSProduct.sol contract which is outside of the v2 core router proxy
 */

library RateOracleManagerStorage {
    bytes32 private constant _SLOT_ORACLE_MANAGER = keccak256(abi.encode("xyz.voltz.RateOracleManager"));

    struct Data {
        /**
         * @dev The oracle manager address.
         */
        address oracleManagerAddress;
    }

    /**
     * @dev Loads the singleton storage info about the oracle manager.
     */
    function load() internal pure returns (Data storage oracleManager) {
        bytes32 s = _SLOT_ORACLE_MANAGER;
        assembly {
            oracleManager.slot := s
        }
    }
}

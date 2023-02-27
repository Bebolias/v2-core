// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
/**
 * @title Represents Oracle Manager
 */

library OracleManagerStorage {
    bytes32 private constant _SLOT_ORACLE_MANAGER = keccak256(abi.encode("xyz.voltz.OracleManager"));

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

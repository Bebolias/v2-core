// https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
pragma solidity >=0.8.19;

/**
 * @title Object for storing appoved periphery address.
 */
library Periphery {

    struct Data {
        /**
         * @dev Periphery address.
         */
        address peripheryAddress;
    }

    /**
     * @dev Returns the account stored at the specified account id.
     */
    function load() internal pure returns (Data storage periphery) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Periphery"));
        assembly {
            periphery.slot := s
        }
    }

    /**
     * @dev Sets the approved Periphery address.
     */
    function setPeriphery(address _peripheryAddress) internal {
        Data storage periphery = load();
        periphery.peripheryAddress = _peripheryAddress;
    }

    /**
     * @dev Checks if given address is the periphery address.
     */
    function isPeriphery(address _peripheryAddress) internal view returns (bool) {
        Data storage periphery = load();
        return _peripheryAddress == periphery.peripheryAddress;
    }
}

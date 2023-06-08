// https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
pragma solidity >=0.8.19;

/**
 * @title Module for setting allowed periphery address.
 */
interface IPeripheryModule {

    /**
     * @dev Sets the approved periphery address, which can pe address 0 
     * in case no periphery is allowed. Msg.sender must me the Proxy owner.
     */
    function setPeriphery(address _peripheryAddress) external;
}

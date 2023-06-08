// https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
pragma solidity >=0.8.19;

import "../storage/Periphery.sol";
import "../interfaces/IPeripheryModule.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

/**
 * @title Module for setting the allowed periphery address.
 * @dev See IPeripheryModule.
 */
contract PeripheryModule is IPeripheryModule {

    /**
     * @inheritdoc IPeripheryModule
     */
    function setPeriphery(address _peripheryAddress) external override {
        OwnableStorage.onlyOwner();
        Periphery.setPeriphery(_peripheryAddress);
    }
}

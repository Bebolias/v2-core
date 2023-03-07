//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../proxy/UUPSImplementation.sol";
import "../../storage/OwnableStorage.sol";

contract BaseUpgradeModule is UUPSImplementation {
    function upgradeTo(address newImplementation) public override {
        OwnableStorage.onlyOwner();
        _upgradeTo(newImplementation);
    }
}

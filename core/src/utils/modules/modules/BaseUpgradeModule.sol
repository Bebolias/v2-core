//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../contracts/proxy/UUPSImplementation.sol";
import "../../contracts/storage/OwnableStorage.sol";

contract BaseUpgradeModule is UUPSImplementation {
    function upgradeTo(address newImplementation) public override {
        OwnableStorage.onlyOwner();
        _upgradeTo(newImplementation);
    }
}

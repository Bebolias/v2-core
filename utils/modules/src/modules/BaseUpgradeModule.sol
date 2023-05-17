pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/proxy/UUPSImplementation.sol";
import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";

contract BaseUpgradeModule is UUPSImplementation {
    function upgradeTo(address newImplementation) public override {
        OwnableStorage.onlyOwner();
        _upgradeTo(newImplementation);
    }
}

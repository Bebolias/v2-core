//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./UpgradeModule.sol";
import "./OwnerModule.sol";

// todo: this needs more documentation and exploration
// The below contract is only used during initialization as a kernel for the first release which the system can be upgraded onto.
// Subsequent upgrades will not need this module bundle

// solhint-disable-next-line no-empty-blocks
contract InitialModuleBundle is OwnerModule, UpgradeModule { }

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/core/src/interfaces/IAccountModule.sol";
import "../storage/Config.sol";

/**
 * @title Performs access control checks.
 */
library AccessControl {
    error NotOwner(address sender, uint128 accountId, address owner);

    function onlyOwner(uint128 accountId) internal view {
        address coreProxyAddress = Config.load().VOLTZ_V2_CORE_PROXY;

        address owner = IAccountModule(coreProxyAddress).getAccountOwner(accountId);

        if (msg.sender != owner) {
            revert NotOwner(msg.sender, accountId, owner);
        }
    }
}

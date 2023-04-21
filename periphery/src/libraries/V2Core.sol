// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/core/src/interfaces/ICollateralModule.sol";
import "../storage/Config.sol";

/**
 * @title Perform withdrawals and deposits to and from the v2 collateral module
 */
library V2Core {
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) internal {
        ICollateralModule(Config.load().VOLTZ_V2_CORE_PROXY).deposit(accountId, collateralType, tokenAmount);
    }

    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) internal {
        ICollateralModule(Config.load().VOLTZ_V2_CORE_PROXY).withdraw(accountId, collateralType, tokenAmount);
    }
}

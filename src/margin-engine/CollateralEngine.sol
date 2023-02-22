//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../accounts/storage/Account.sol";

/**
 * @title Module for managing user collateral.
 * @dev See ICollateralEngine.
 */
contract CollateralEngine is ICollateralEngine {
    using ERC20Helper for address;
    using Account for Account.Data;
    using AccountRBAC for AccountRBAC.Data;

    /**
     * @inheritdoc ICollateralEngine
     */
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        
    }
}

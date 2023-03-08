//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/ICollateralModule.sol";
import "../storage/Account.sol";
import "../storage/CollateralConfiguration.sol";
import "../utils/contracts//token/ERC20Helper.sol";
import "../storage/Collateral.sol";
/**
 * @title Module for managing user collateral.
 * @dev See ICollateralModule.
 */

contract CollateralModule is ICollateralModule {
    using ERC20Helper for address;
    using CollateralConfiguration for CollateralConfiguration.Data;
    using Account for Account.Data;
    using AccountRBAC for AccountRBAC.Data;
    using Collateral for Collateral.Data;
    using SafeCastI256 for int256;

    /**
     * @inheritdoc ICollateralModule
     */
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        CollateralConfiguration.collateralEnabled(collateralType);
        Account.Data storage account = Account.exists(accountId);
        address depositFrom = msg.sender;
        address self = address(this);
        uint256 allowance = IERC20(collateralType).allowance(depositFrom, self);
        if (allowance < tokenAmount) {
            revert IERC20.InsufficientAllowance(tokenAmount, allowance);
        }
        collateralType.safeTransferFrom(depositFrom, self, tokenAmount);
        account.collaterals[collateralType].increaseCollateralBalance(tokenAmount);
        emit Deposited(accountId, collateralType, tokenAmount, msg.sender);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(accountId, msg.sender);

        account.collaterals[collateralType].decreaseCollateralBalance(tokenAmount);

        account.imCheck();

        collateralType.safeTransfer(msg.sender, tokenAmount);

        emit Withdrawn(accountId, collateralType, tokenAmount, msg.sender);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function getAccountCollateralBalance(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (uint256 collateralBalance)
    {
        return Account.load(accountId).getCollateralBalance(collateralType);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function getAccountCollateralBalanceAvailable(
        uint128 accountId,
        address collateralType
    )
        external
        override
        returns (uint256 collateralBalanceAvailable)
    {
        return Account.load(accountId).getCollateralBalanceAvailable(collateralType);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function getTotalAccountValue(uint128 accountId) external view override returns (int256 totalAccountValue) {
        return Account.load(accountId).getTotalAccountValue();
    }
}

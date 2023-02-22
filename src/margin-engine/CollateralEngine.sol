//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../accounts/storage/Account.sol";
import "./storage/CollateralConfiguration.sol";

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
        CollateralConfiguration.collateralEnabled(collateralType);
        Account.exists(accountId);
        Account.Data storage account = Account.load(accountId);
        address depositFrom = msg.sender;
        address self = address(this);
        uint256 allowance = IERC20(collateralType).allowance(depositFrom, self);
        if (allowance < tokenAmount) {
            revert IERC20.InsufficientAllowance(tokenAmount, allowance);
        }
        collateralType.safeTransferFrom(depositFrom, self, tokenAmount);
        // account.collaterals[collateralType].increaseAvailableCollateral(
        //     CollateralConfiguration.load(collateralType).convertTokenToSystemAmount(tokenAmount)
        // );
        emit Deposited(accountId, collateralType, tokenAmount, msg.sender);
    }

    /**
     * @inheritdoc ICollateralEngine
     */
    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        // todo: revisit loadAccountAndValidatePermissionAndTimeout
        Account.Data storage account = Account.loadAccountAndValidatePermissionAndTimeout(
            accountId, AccountRBAC._WITHDRAW_PERMISSION, uint256(Config.read(_CONFIG_TIMEOUT_WITHDRAW))
        );

        uint256 tokenAmountD18 = CollateralConfiguration.load(collateralType).convertTokenToSystemAmount(tokenAmount);

        (uint256 totalDeposited, uint256 totalAssigned, uint256 totalLocked) =
            account.getCollateralTotals(collateralType);

        // The amount that cannot be withdrawn from the protocol is the max of either
        // locked collateral or delegated collateral.
        uint256 unavailableCollateral = totalLocked > totalAssigned ? totalLocked : totalAssigned;

        uint256 availableForWithdrawal = totalDeposited - unavailableCollateral;
        if (tokenAmountD18 > availableForWithdrawal) {
            revert InsufficientAccountCollateral(tokenAmountD18);
        }

        account.collaterals[collateralType].decreaseAvailableCollateral(tokenAmountD18);

        collateralType.safeTransfer(msg.sender, tokenAmount);

        emit Withdrawn(accountId, collateralType, tokenAmount, msg.sender);
    }
}

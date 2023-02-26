//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/ICollateralEngine.sol";
import "../accounts/storage/Account.sol";
import "./storage/CollateralConfiguration.sol";
import "../utils/contracts/token/ERC20Helper.sol";
import "./storage/Collateral.sol";
/**
 * @title Module for managing user collateral.
 * @dev See ICollateralEngine.
 */

contract CollateralEngine is ICollateralEngine {
    using ERC20Helper for address;
    using CollateralConfiguration for CollateralConfiguration.Data;
    using Account for Account.Data;
    using AccountRBAC for AccountRBAC.Data;
    using Collateral for Collateral.Data;
    using SafeCastI256 for int256;

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
        account.collaterals[collateralType].increaseCollateralBalance(
            CollateralConfiguration.load(collateralType).convertTokenToSystemAmount(tokenAmount)
        );
        emit Deposited(accountId, collateralType, tokenAmount, msg.sender);
    }

    /**
     * @inheritdoc ICollateralEngine
     */
    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(accountId);

        uint256 tokenAmountD18 = CollateralConfiguration.load(collateralType).convertTokenToSystemAmount(tokenAmount);

        account.collaterals[collateralType].decreaseCollateralBalance(tokenAmountD18);

        account.imCheck();

        collateralType.safeTransfer(msg.sender, tokenAmount);

        emit Withdrawn(accountId, collateralType, tokenAmount, msg.sender);
    }

    /**
     * @inheritdoc ICollateralEngine
     */
    function getAccountCollateralBalance(uint128 accountId, address collateralType)
        external
        view
        override
        returns (uint256 collateralBalance)
    {
        return Account.load(accountId).getCollateralBalance(collateralType);
    }
    /**
     * @inheritdoc ICollateralEngine
     */

    function getAccountCollateralBalanceAvailable(uint128 accountId, address collateralType)
        external
        view
        override
        returns (uint256 collateralBalanceAvailable)
    {
        return Account.load(accountId).getCollateralBalanceAvailable(collateralType);
    }

    /**
     * @inheritdoc ICollateralEngine
     */
    function getTotalAccountValue(uint128 accountId) external view override returns (int256 totalAccountValue) {
        return Account.load(accountId).getTotalAccountValue();
    }

    /**
     * @inheritdoc ICollateralEngine
     */
    function cashflowPropagation(uint128 accountId, address collateralType, int256 tokenAmount) external {
        Account.Data storage account = Account.load(accountId);
        // todo: needs a feature flag since since this function can only be called by [...]
        // todo: check if tokenAmount == 0, don't do anything
        if (tokenAmount > 0) {
            account.collaterals[collateralType].increaseCollateralBalance(
                CollateralConfiguration.load(collateralType).convertTokenToSystemAmount(tokenAmount.toUint())
            );
        } else {
            account.collaterals[collateralType].decreaseCollateralBalance(
                CollateralConfiguration.load(collateralType).convertTokenToSystemAmount((-tokenAmount).toUint())
            );
        }
    }
}

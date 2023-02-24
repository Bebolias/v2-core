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

        uint256 collateralBalanceD18 = account.getCollateralBalance(collateralType);

        // todo: include im logic from python

        account.collaterals[collateralType].decreaseCollateralBalance(tokenAmountD18);

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
        returns (uint256 amountD18)
    {}

    /**
     * @inheritdoc ICollateralEngine
     */
    function getTotalAccountValue(uint128 accountId) external view override returns (uint256 totalAccountValue) {}

    /**
     * @inheritdoc ICollateralEngine
     */
    function cashflowPropagation(uint128 accountId, address collateralType, int256 tokenAmount) external {}
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/ICollateralConfigurationModule.sol";
import "../utils/contracts//helpers/SetUtil.sol";
import "../storage/CollateralConfiguration.sol";
import "../utils/contracts//storage/OwnableStorage.sol";

/**
 * @title Module for configuring system wide collateral.
 * @dev See ICollateralConfigurationModule.
 */
contract CollateralConfigurationModule is ICollateralConfigurationModule {
    using SetUtil for SetUtil.AddressSet;
    using CollateralConfiguration for CollateralConfiguration.Data;

    /**
     * @inheritdoc ICollateralConfigurationModule
     */
    function configureCollateral(CollateralConfiguration.Data memory config) external override {
        OwnableStorage.onlyOwner();

        CollateralConfiguration.set(config);

        emit CollateralConfigured(config.tokenAddress, config);
    }

    /**
     * @inheritdoc ICollateralConfigurationModule
     */
    function getCollateralConfigurations(bool hideDisabled)
        external
        view
        override
        returns (CollateralConfiguration.Data[] memory)
    {
        SetUtil.AddressSet storage collateralTypes = CollateralConfiguration.loadAvailableCollaterals();
        uint256 numCollaterals = collateralTypes.length();

        uint256 returningConfig = 0;
        for (uint256 i = 1; i <= numCollaterals; i++) {
            address collateralType = collateralTypes.valueAt(i);
            CollateralConfiguration.Data storage collateral = CollateralConfiguration.load(collateralType);

            if (!hideDisabled || collateral.depositingEnabled) {
                returningConfig++;
            }
        }

        CollateralConfiguration.Data[] memory filteredCollaterals = new CollateralConfiguration.Data[](returningConfig);

        returningConfig = 0;
        for (uint256 i = 1; i <= numCollaterals; i++) {
            address collateralType = collateralTypes.valueAt(i);
            CollateralConfiguration.Data storage collateral = CollateralConfiguration.load(collateralType);

            if (!hideDisabled || collateral.depositingEnabled) {
                filteredCollaterals[returningConfig++] = collateral;
            }
        }

        return filteredCollaterals;
    }

    /**
     * @inheritdoc ICollateralConfigurationModule
     */
    function getCollateralConfiguration(address collateralType)
        external
        pure
        override
        returns (CollateralConfiguration.Data memory)
    {
        return CollateralConfiguration.load(collateralType);
    }
}

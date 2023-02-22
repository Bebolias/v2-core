//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Tracks protocol-wide settings for each collateral type, as well as helper functions for it, such as retrieving its current price from the oracle manager -> relevant for multi-collateral.
 */
library CollateralConfiguration {
    bytes32 private constant _SLOT_AVAILABLE_COLLATERALS =
        keccak256(abi.encode("io.voltz.CollateralConfiguration_availableCollaterals"));

    /**
     * @dev Thrown when the token address of a collateral cannot be found.
     */
    error CollateralNotFound();

    /**
     * @dev Thrown when deposits are disabled for the given collateral type.
     * @param collateralType The address of the collateral type for which depositing was disabled.
     */
    error CollateralDepositDisabled(address collateralType);

    struct Data {
        /**
         * @dev Allows the owner to control deposits and delegation of collateral types.
         */
        bool depositingEnabled;
        /**
         * @dev Amount of tokens to award when an account is liquidated.
         * @dev todo: consider having a minimum amount that accounts need to have deposited to help prevent spamming on the protocol.
         * @dev could be -> if zero, set it to be equal to the liquidationRewardD18
         */
        uint256 liquidationRewardD18;
        /**
         * @dev The oracle manager node id which reports the current price for this collateral type.
         */
        // bytes32 oracleNodeId;
        /**
         * @dev The token address for this collateral type.
         */
        address tokenAddress;
    }

    /**
     * @dev Loads the CollateralConfiguration object for the given collateral type.
     * @param token The address of the collateral type.
     * @return collateralConfiguration The CollateralConfiguration object.
     */
    function load(address token) internal pure returns (Data storage collateralConfiguration) {
        bytes32 s = keccak256(abi.encode("io.voltz.CollateralConfiguration", token));
        assembly {
            collateralConfiguration.slot := s
        }
    }

    /**
     * @dev Loads all available collateral types configured in the protocol
     * @return availableCollaterals An array of addresses, one for each collateral type supported by the protocol
     */
    function loadAvailableCollaterals() internal pure returns (SetUtil.AddressSet storage availableCollaterals) {
        bytes32 s = _SLOT_AVAILABLE_COLLATERALS;
        assembly {
            availableCollaterals.slot := s
        }
    }

    /**
     * @dev Configures a collateral type.
     * @param config The CollateralConfiguration object with all the settings for the collateral type being configured.
     */
    function set(Data memory config) internal {
        SetUtil.AddressSet storage collateralTypes = loadAvailableCollaterals();

        if (!collateralTypes.contains(config.tokenAddress)) {
            collateralTypes.add(config.tokenAddress);
        }

        Data storage storedConfig = load(config.tokenAddress);

        storedConfig.tokenAddress = config.tokenAddress;
        storedConfig.liquidationRewardD18 = config.liquidationRewardD18;
        storedConfig.depositingEnabled = config.depositingEnabled;
    }
}

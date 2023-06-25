/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "../storage/AccessPassConfiguration.sol";

/**
 * @title Module for configuring the access pass nft
 * @notice Allows the owner to configure the access pass nft
 */
interface IAccessPassConfigurationModule {

    /**
     * @notice Emitted when the access pass configuration is created or updated
     * @param config The object with the newly configured details.
     * @param blockTimestamp The current block timestamp.
     */
    event AccessPassConfigured(AccessPassConfiguration.Data config, uint256 blockTimestamp);


    /**
     * @notice Creates or updates the access pass configuration
     * @param config The AccessPassConfiguration object describing the new configuration.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner of the protocol.
     *
     * Emits a {AccessPassConfigured} event.
     *
     */
    function configureAccessPass(AccessPassConfiguration.Data memory config) external;


    /**
     * @notice Returns detailed information on protocol-wide risk configuration
     * @return config The configuration object describing the protocol-wide risk configuration
     */
    function getAccessPassConfiguration() external pure returns (AccessPassConfiguration.Data memory config);
}

/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

/// @dev The RateOracle is used for two purposes on the Voltz Protocol
/// @dev Settlement: in order to be able to settle IRS positions after the termEndTimestamp of a given AMM
/// @dev Margin Engine Computations: getApyFromTo is used by the MarginEngine
/// @dev It is necessary to produce margin requirements for Trader and Liquidity Providers
interface IRateOracle is IERC165 {
    /// @notice Get the last updated liquidity index with the timestamp at which it was written
    /// This data point must be a known data point from the source of the data, and not extrapolated or interpolated by us.
    /// The source and expected values of "lquidity index" may differ by rate oracle type. All that
    /// matters is that we can divide one "liquidity index" by another to get the factor of growth between the two timestamps.
    /// For example if we have indices of { (t=0, index=5), (t=100, index=5.5) }, we can divide 5.5 by 5 to get a growth factor
    /// of 1.1, suggesting that 10% growth in capital was experienced between timesamp 0 and timestamp 100.
    /// @dev The liquidity index is normalised to a UD60x18 for storage, so that we can perform consistent math across all rates.
    /// @dev This function should revert if a valid rate cannot be discerned
    /// @return timestamp the timestamp corresponding to the known rate (could be the current time, or a time in the past)
    /// @return liquidityIndex the liquidity index value, as a decimal scaled up by 10^18 for storage in a uint256
    function getLastUpdatedIndex() external view returns (uint32 timestamp, UD60x18 liquidityIndex);

    /// @notice Get the current liquidity index for the rate oracle
    /// This data point may be extrapolated from data known data points available in the underlying platform.
    /// The source and expected values of "lquidity index" may differ by rate oracle type. All that
    /// matters is that we can divide one "liquidity index" by another to get the factor of growth between the two timestamps.
    /// For example if we have indices of { (t=0, index=5), (t=100, index=5.5) }, we can divide 5.5 by 5 to get a growth factor
    /// of 1.1, suggesting that 10% growth in capital was experienced between timesamp 0 and timestamp 100.
    /// @dev The liquidity index is normalised to a UD60x18 for storage, so that we can perform consistent math across all rates.
    /// @dev This function should revert if a valid rate cannot be discerned
    /// @return liquidityIndex the liquidity index value, as a decimal scaled up by 10^18 for storage in a uint256
    function getCurrentIndex() external view returns (UD60x18 liquidityIndex);
}

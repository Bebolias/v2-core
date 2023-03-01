// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/// @title Interface for the module for managing rate oracles connected to the Dated IRS Product
interface IRateOracleManager {
    /**
     * @notice Thrown when the specified marketId has not been registered in the system
     */
    error RateOracleNotRegistered(bytes32 marketId);

    /**
     * @notice Emitted when `registerRateOracle` is called.
     * @param marketId The id of the market (e.g. aUSDC lend) associated with the rate oracle
     */
    event RateOracleNodeRegistered(bytes32 marketId);

    /**
     * @notice Requests a rate index snapshot at a maturity timestamp of a given interest rate market (e.g. aUSDC lend)
     * @param marketId Id of the market (e.g. aUSDC lend) for which we're requesting a rate index value
     * @param maturityTimestamp Maturity Timestamp of a given irs market that's requesting the index value for settlement purposes
     * @return rateIndexAtMaturity Rate index at the requested maturityTimestamp
     */
    function getRateIndexAtMaturity(uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 rateIndexAtMaturity);

    /**
     * @notice Requests a rate index snapshot at a maturity timestamp of a given interest rate market (e.g. aUSDC borrow)
     * @param marketId Id of the market (e.g. aUSDC lend) for which we're requesting the current rate index value
     * @return rateIndexCurrent Rate index at the current timestamp
     */
    function getRateIndexCurrent(uint128 marketId) external view returns (uint256 rateIndexCurrent);

    /**
     * @notice Requests the geometric time weighted average fixed rate for a given marketId + maturityTimestamp pai
     * @param marketId Id of the interest rate swap market (e.g. aUSDC lend) for which we're requesting the gwap
     * @param maturityTimestamp The timestamp at which the dated irs market matures
     * @return datedIRSGwap Geometric time weightred average fixed rate
     */
    function getDatedIRSGwap(uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 datedIRSGwap);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/// @title Interface for a variable rate oracle contract
interface IVariableRateOracle {
    /**
     * @notice Requests the current rate index value provided by a variable rate oracle
     * @return rateIndexCurrent Current rate index of a given variable rate oracle (e.g. aUSDC lend or cUSDC borrow)
     */
    function getRateIndexCurrent() external view returns (uint256 rateIndexCurrent);
}

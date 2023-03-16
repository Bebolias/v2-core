// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;

import "../../src/interfaces/IRateOracle.sol";

contract MockRateOracle is IRateOracle {
    IAaveV3LendingPool public aaveLendingPool;
    address public immutable underlying;

    using PRBMathCastingUint256 for uint256;

    uint40 public lastUpdatedTimestamp;
    uint256 public lastUpdatedLiquidityIndex;

    /// @inheritdoc IRateOracle
    function getLastUpdatedIndex() public view override returns (uint40 timestamp, UD60x18 liquidityIndex) {
        return (Time.blockTimestampTruncated(), ud(lastUpdatedLiquidityIndex / 1e9));
    }

    function setLastUpdatedIndex(uint256 _lastUpdatedLiquidityIndex) public {
        lastUpdatedLiquidityIndex = _lastUpdatedLiquidityIndex;
    }

    /// @inheritdoc IRateOracle
    function getCurrentIndex() external view override returns (UD60x18 liquidityIndex) {
        return ud(lastUpdatedLiquidityIndex / 1e9);
    }

    // why is this public?
    /// @inheritdoc IRateOracle
    function interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    ) public pure returns (UD60x18 interpolatedIndex) {
        return ud(0);
    }
}

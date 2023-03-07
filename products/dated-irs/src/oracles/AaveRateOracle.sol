// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;

import "../interfaces/IRateOracle.sol";
import "../externalInterfaces/IAaveV3LendingPool.sol";
import "../utils/contracts//helpers/Time.sol";
// import "../rate_oracles/CompoundingRateOracle.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {PRBMathCastingUint256} from "@prb/math/casting/Uint256.sol";

contract AaveRateOracle is IRateOracle {
    IAaveV3LendingPool public aaveLendingPool;
    address public immutable underlying;

    using PRBMathCastingUint256 for uint256;

    constructor(IAaveV3LendingPool _aaveLendingPool, address _underlying) {
        require(address(_aaveLendingPool) != address(0), "aave pool must exist");

        underlying = _underlying;
        aaveLendingPool = _aaveLendingPool;
    }

    /// @inheritdoc IRateOracle
    function getLastUpdatedIndex() public view override returns (uint40 timestamp, UD60x18 liquidityIndex) {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedIncome(underlying);
        // if (liquidityIndex == 0) {
        //     revert CustomErrors.AavePoolGetReserveNormalizedIncomeReturnedZero();
        // }

        // Convert index from Aave's "ray" (decimal scaled by 10^27) to UD60x18 (decimal scaled by 10^18)
        return (Time.blockTimestampTruncated(), ud(liquidityIndexInRay / 1e9));
    }

    /// @inheritdoc IRateOracle
    function getCurrentIndex() external view override returns (UD60x18 liquidityIndex) {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedIncome(underlying);
        // if (liquidityIndex == 0) {
        //     revert CustomErrors.AavePoolGetReserveNormalizedIncomeReturnedZero();
        // }

        // Convert index from Aave's "ray" (decimal scaled by 10^27) to UD60x18 (decimal scaled by 10^18)
        return ud(liquidityIndexInRay / 1e9);
    }

    /// @inheritdoc IRateOracle
    function interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    ) public pure returns (UD60x18 interpolatedIndex) {
        if (atOrAfterTimestamp == queryTimestamp) {
            return atOrAfterIndex;
        }

        // TODO: fix calculation to account for compounding (is there a better way than calculating an APY and applying it?)
        UD60x18 totalDelta = atOrAfterIndex.sub(beforeIndex);
        UD60x18 proportionOfPeriodElapsed = (atOrAfterTimestamp - queryTimestamp).intoUD60x18().div(
            (atOrAfterTimestamp - beforeTimestamp).intoUD60x18()
        );
        return proportionOfPeriodElapsed.mul(totalDelta).add(beforeIndex);
    }
}

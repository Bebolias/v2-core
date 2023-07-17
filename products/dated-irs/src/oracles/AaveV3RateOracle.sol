/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "../interfaces/IRateOracle.sol";
import "../interfaces/external/IAaveV3LendingPool.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

contract AaveV3RateOracle is IRateOracle {
    IAaveV3LendingPool public aaveLendingPool;
    address public immutable underlying;

    error AavePoolGetReserveNormalizedIncomeReturnedZero();

    constructor(IAaveV3LendingPool _aaveLendingPool, address _underlying) {
        require(address(_aaveLendingPool) != address(0), "aave pool must exist");

        underlying = _underlying;
        aaveLendingPool = _aaveLendingPool;
    }

    /// @inheritdoc IRateOracle
    function getLastUpdatedIndex() public view override returns (uint32 timestamp, UD60x18 liquidityIndex) {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedIncome(underlying);

         if (liquidityIndexInRay == 0) {
             revert AavePoolGetReserveNormalizedIncomeReturnedZero();
         }

        liquidityIndex = ud(liquidityIndexInRay / 1e9);

        return (Time.blockTimestampTruncated(), liquidityIndex);
    }

    /// @inheritdoc IRateOracle
    function getCurrentIndex() external view override returns (UD60x18 liquidityIndex) {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedIncome(underlying);

        if (liquidityIndexInRay == 0) {
            revert AavePoolGetReserveNormalizedIncomeReturnedZero();
        }

        liquidityIndex = ud(liquidityIndexInRay / 1e9);
        return liquidityIndex;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external pure override(IERC165) returns (bool) {
        return interfaceId == type(IRateOracle).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

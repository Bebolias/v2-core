pragma solidity =0.8.19;

import "../../src/oracles/AaveRateOracle.sol";
import "../../src/interfaces/IRateOracle.sol";
import "./MockAaveLendingPool.sol";
import "../../src/externalInterfaces/IAaveV3LendingPool.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol";

contract MockRateOracle is IRateOracle {
    uint32 public lastUpdatedTimestamp;
    uint256 public lastUpdatedLiquidityIndex;

    /// @inheritdoc IRateOracle
    function getLastUpdatedIndex() public view override returns (uint32 timestamp, UD60x18 liquidityIndex) {
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
    function interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    )
        public
        pure
        returns (UD60x18 interpolatedIndex)
    {
        interpolatedIndex = beforeIndex.add(atOrAfterIndex).div(ud(2e18));
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool) {
        return interfaceId == type(IRateOracle).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

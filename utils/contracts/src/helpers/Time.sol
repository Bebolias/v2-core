// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;

library Time {
    // uint256 public constant SECONDS_IN_DAY_WAD = 86400e18;
    uint256 public constant SECONDS_IN_YEAR_WAD = 31540000e18;

    // /// @notice Calculate block.timestamp to wei precision
    // /// @return Current timestamp in wei-seconds (1/1e18)
    // function blockTimestampScaled() internal view returns (uint256) {
    //     // solhint-disable-next-line not-rely-on-time
    //     return PRBMathUD60x18.fromUint(block.timestamp);
    // }

    /// @dev Returns the block timestamp truncated to 32 bits, checking for overflow.
    function blockTimestampTruncated() internal view returns (uint32) {
        return timestampAsUint32(block.timestamp);
    }

    function timestampAsUint32(uint256 _timestamp) internal pure returns (uint32 timestamp) {
        require((timestamp = uint32(_timestamp)) == _timestamp, "TSOFLOW");
    }

    function timeDeltaAnnualizedWad(uint32 timestamp) internal pure returns (uint32 timeDelta) {
        if (timestamp > blockTimestampTruncated()) {
            uint256 timeDeltaUnchecked = (timestamp - blockTimestampTruncated()) * 1e18 / SECONDS_IN_YEAR_WAD;
            require((timeDelta = uint32(timeDeltaUnchecked)) == timeDeltaUnchecked, "TOFLOW");
        }
        
    }

    // function isCloseToMaturityOrBeyondMaturity(uint256 termEndTimestampWad)
    //     internal
    //     view
    //     returns (bool vammInactive)
    // {
    //     return
    //         Time.blockTimestampScaled() + SECONDS_IN_DAY_WAD >=
    //         termEndTimestampWad;
    // }
}

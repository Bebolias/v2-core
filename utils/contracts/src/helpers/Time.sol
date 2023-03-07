// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;

library Time {
    uint256 public constant SECONDS_IN_DAY_WAD = 86400e18;

    // /// @notice Calculate block.timestamp to wei precision
    // /// @return Current timestamp in wei-seconds (1/1e18)
    // function blockTimestampScaled() internal view returns (uint256) {
    //     // solhint-disable-next-line not-rely-on-time
    //     return PRBMathUD60x18.fromUint(block.timestamp);
    // }

    /// @dev Returns the block timestamp truncated to 32 bits, checking for overflow.
    function blockTimestampTruncated() internal view returns (uint40) {
        return timestampAsUint40(block.timestamp);
    }

    function timestampAsUint40(uint256 _timestamp) internal pure returns (uint40 timestamp) {
        require((timestamp = uint40(_timestamp)) == _timestamp, "TSOFLOW");
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

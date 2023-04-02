// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
/**
 * @title See SafeCast.sol.
 * note this is a copy of the Casting contracts from the current PRBMath version
 */

import { UD60x18, unwrap as uUnwrap } from "@prb/math/UD60x18.sol";
import { SD59x18, unwrap as sUnwrap } from "@prb/math/SD59x18.sol";
import "./SafeCastU256.sol";
import "./SafeCastI256.sol";

library SafeCastPrbMath {
    using { uUnwrap } for UD60x18;
    using { sUnwrap } for SD59x18;
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    error OverflowSD59x18ToUD60x18();
    error OverflowUD60x18ToSD59x18();

    function toSD59x18(UD60x18 x) internal pure returns (SD59x18) {
        if (uUnwrap(x) > uint256(type(int256).max)) {
            revert OverflowUD60x18ToSD59x18();
        }

        return SD59x18.wrap(x.uUnwrap().toInt());
    }

    function toUD60x18(SD59x18 x) internal pure returns (UD60x18) {
        if (sUnwrap(x) < 0) {
            revert OverflowSD59x18ToUD60x18();
        }

        return UD60x18.wrap(x.sUnwrap().toUint());
    }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { UD60x18, mul as mulUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, mul as mulSD59x18} from "@prb/math/SD59x18.sol";
import "./SafeCast.sol";

using SafeCastU256 for uint256;

function mulUDxUint(UD60x18 a, uint256 b) pure returns (uint256) {
  return UD60x18.unwrap(mulUD60x18(a, UD60x18.wrap(b)));
}

function mulUDxInt(UD60x18 a, int256 b) pure returns (int256) {
  return mulSDxUint(SD59x18.wrap(b), UD60x18.unwrap(a));
}

function mulSDxInt(SD59x18 a, int256 b) pure returns (int256) {
  return SD59x18.unwrap(mulSD59x18(a, SD59x18.wrap(b)));
}

function mulSDxUint(SD59x18 a, uint256 b) pure returns (int256) {
  return SD59x18.unwrap(mulSD59x18(a, SD59x18.wrap(b.toInt())));
}
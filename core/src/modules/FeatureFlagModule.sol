/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import {FeatureFlagModule as BaseFeatureFlagModule} from
    "@voltz-protocol/util-modules/src/modules/FeatureFlagModule.sol";

/**
 * @title Module that allows disabling certain system features.
 *
 * Users will not be able to interact with certain functions associated to disabled features.
 */
// solhint-disable-next-line no-empty-blocks
contract FeatureFlagModule is BaseFeatureFlagModule {}

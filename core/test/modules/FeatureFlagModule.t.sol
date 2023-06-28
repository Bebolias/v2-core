/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/FeatureFlagModule.sol";


contract ExposedFeatureFlagModule is FeatureFlagModule {
    constructor() {
    }
}


contract FeatureFlagModuleTest is Test {
    event FeatureFlagAllowAllSet(bytes32 indexed feature, bool allowAll);

    ExposedFeatureFlagModule internal featureFlagModule;
    address internal owner = vm.addr(1);
    bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";

    function setUp() public {
        featureFlagModule = new ExposedFeatureFlagModule();

        vm.store(
            address(featureFlagModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );
    }

    function test_FeatureFlagAllowAll() public {
        vm.prank(owner);
        featureFlagModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);
        // Expect FeatureFlagAllowAllSet event
        vm.expectEmit(address(featureFlagModule));
        emit FeatureFlagAllowAllSet(_GLOBAL_FEATURE_FLAG, true);
        vm.prank(owner);
        featureFlagModule.setFeatureFlagAllowAll(_GLOBAL_FEATURE_FLAG, true);

        bool isAllowAll = featureFlagModule.getFeatureFlagAllowAll(_GLOBAL_FEATURE_FLAG);
        bool isDenyAll = featureFlagModule.getFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG);
        assertEq(isAllowAll, true);
        assertEq(isDenyAll, false);
    }

}
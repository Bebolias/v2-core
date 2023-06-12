/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/ProtocolRiskConfiguration.sol";

import {UD60x18} from "@prb/math/UD60x18.sol";

contract ExposedProtocolRiskConfiguration {
    // Mock support
    function getProtocolRiskConfiguration() external pure returns (ProtocolRiskConfiguration.Data memory) {
        return ProtocolRiskConfiguration.load();
    }

    // Exposed functions
    function load() external pure returns (bytes32 s) {
        ProtocolRiskConfiguration.Data storage data = ProtocolRiskConfiguration.load();
        assembly {
            s := data.slot
        }
    }

    function set(ProtocolRiskConfiguration.Data memory config) external {
        ProtocolRiskConfiguration.set(config);
    }
}

contract ProtocolRiskConfigurationTest is Test {
    ExposedProtocolRiskConfiguration internal protocolRiskConfiguration;

    function setUp() public {
        protocolRiskConfiguration = new ExposedProtocolRiskConfiguration();
    }

    function test_Load() public {
        bytes32 slot = protocolRiskConfiguration.load();

        assertEq(slot, keccak256(abi.encode("xyz.voltz.ProtocolRiskConfiguration")));
    }

    function test_Set() public {
        protocolRiskConfiguration.set(
            ProtocolRiskConfiguration.Data({
                imMultiplier: UD60x18.wrap(2e18),
                liquidatorRewardParameter: UD60x18.wrap(5e16)
            })
        );

        ProtocolRiskConfiguration.Data memory config = protocolRiskConfiguration.getProtocolRiskConfiguration();

        assertEq(UD60x18.unwrap(config.imMultiplier), 2e18);
        assertEq(UD60x18.unwrap(config.liquidatorRewardParameter), 5e16);
    }

    function test_Set_Twice() public {
        protocolRiskConfiguration.set(
            ProtocolRiskConfiguration.Data({
                imMultiplier: UD60x18.wrap(2e18),
                liquidatorRewardParameter: UD60x18.wrap(5e16)
            })
        );

        protocolRiskConfiguration.set(
            ProtocolRiskConfiguration.Data({
                imMultiplier: UD60x18.wrap(4e18),
                liquidatorRewardParameter: UD60x18.wrap(10e16)
            })
        );

        ProtocolRiskConfiguration.Data memory config = protocolRiskConfiguration.getProtocolRiskConfiguration();

        assertEq(UD60x18.unwrap(config.imMultiplier), 4e18);
        assertEq(UD60x18.unwrap(config.liquidatorRewardParameter), 10e16);
    }
}

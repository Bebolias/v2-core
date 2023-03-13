// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/storage/ProtocolRiskConfiguration.sol";

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
        protocolRiskConfiguration.set(ProtocolRiskConfiguration.Data({imMultiplier: 2e18, liquidatorRewardParameter: 5e16}));

        ProtocolRiskConfiguration.Data memory config = protocolRiskConfiguration.getProtocolRiskConfiguration();

        assertEq(config.imMultiplier, 2e18);
        assertEq(config.liquidatorRewardParameter, 5e16);
    }

    function test_Set_Twice() public {
        protocolRiskConfiguration.set(ProtocolRiskConfiguration.Data({imMultiplier: 2e18, liquidatorRewardParameter: 5e16}));

        protocolRiskConfiguration.set(ProtocolRiskConfiguration.Data({imMultiplier: 4e18, liquidatorRewardParameter: 10e16}));

        ProtocolRiskConfiguration.Data memory config = protocolRiskConfiguration.getProtocolRiskConfiguration();

        assertEq(config.imMultiplier, 4e18);
        assertEq(config.liquidatorRewardParameter, 10e16);
    }
}

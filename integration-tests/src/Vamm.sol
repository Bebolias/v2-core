pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/proxy/UUPSProxyWithOwner.sol";

import "@voltz-protocol/v2-vamm/src/modules/AccountBalanceModule.sol";
import { FeatureFlagModule as FeatureFlagModuleVamm } from "@voltz-protocol/v2-vamm/src/modules/FeatureFlagModule.sol";
import "@voltz-protocol/v2-vamm/src/modules/OwnerUpgradeModule.sol";
import "@voltz-protocol/v2-vamm/src/modules/PoolConfigurationModule.sol";
import "@voltz-protocol/v2-vamm/src/modules/PoolModule.sol";
import "@voltz-protocol/v2-vamm/src/modules/VammModule.sol";

contract VammRouter is
  AccountBalanceModule,
  FeatureFlagModuleVamm,
  OwnerUpgradeModule,
  PoolConfigurationModule,
  PoolModule,
  VammModule
{}

contract VammProxy is
  UUPSProxyWithOwner,
  VammRouter
{ 
  // solhint-disable-next-line no-empty-blocks
  constructor(address firstImplementation, address initialOwner)
      UUPSProxyWithOwner(firstImplementation, initialOwner)
  {}
}
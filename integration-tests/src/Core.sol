pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/proxy/UUPSProxyWithOwner.sol";

import "@voltz-protocol/core/src/modules/AccountModule.sol";
import "@voltz-protocol/core/src/modules/AssociatedSystemsModule.sol";
import "@voltz-protocol/core/src/modules/CollateralConfigurationModule.sol";
import "@voltz-protocol/core/src/modules/CollateralModule.sol";
import "@voltz-protocol/core/src/modules/FeatureFlagModule.sol";
import "@voltz-protocol/core/src/modules/FeeConfigurationModule.sol";
import "@voltz-protocol/core/src/modules/LiquidationModule.sol";
import "@voltz-protocol/core/src/modules/OwnerUpgradeModule.sol";
import "@voltz-protocol/core/src/modules/PeripheryModule.sol";
import "@voltz-protocol/core/src/modules/ProductModule.sol";
import "@voltz-protocol/core/src/modules/RiskConfigurationModule.sol";

import "@voltz-protocol/core/src/modules/AccountTokenModule.sol";

contract CoreRouter is
  AccountModule, 
  AssociatedSystemsModule,
  CollateralConfigurationModule,
  CollateralModule,
  FeatureFlagModule,
  FeeConfigurationModule,
  LiquidationModule,
  OwnerUpgradeModule,
  PeripheryModule,
  ProductModule,
  RiskConfigurationModule 
{ }

contract CoreProxy is
  UUPSProxyWithOwner,
  CoreRouter
{
  constructor(address firstImplementation, address initialOwner)
      UUPSProxyWithOwner(firstImplementation, initialOwner)
  {}
}

contract AccountNftRouter is AccountTokenModule {}

contract AccountNftProxy is 
  UUPSProxyWithOwner,
  AccountNftRouter
{
  constructor(address firstImplementation, address initialOwner)
      UUPSProxyWithOwner(firstImplementation, initialOwner)
  {}
}

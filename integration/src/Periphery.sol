pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/proxy/UUPSProxyWithOwner.sol";

import "@voltz-protocol/periphery/src/modules/ERC721ReceiverModule.sol";
import "@voltz-protocol/periphery/src/modules/ConfigurationModule.sol";
import "@voltz-protocol/periphery/src/modules/ExecutionModule.sol";
import "@voltz-protocol/periphery/src/modules/OwnerUpgradeModule.sol";

contract PeripheryRouter is
  ERC721ReceiverModule,
  ConfigurationModule,
  ExecutionModule,
  OwnerUpgradeModule
{}

contract PeripheryProxy is
  UUPSProxyWithOwner,
  PeripheryRouter
{ 
  // solhint-disable-next-line no-empty-blocks
  constructor(address firstImplementation, address initialOwner)
      UUPSProxyWithOwner(firstImplementation, initialOwner)
  {}
}
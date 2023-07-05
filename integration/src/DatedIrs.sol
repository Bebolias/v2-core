pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/proxy/UUPSProxyWithOwner.sol";

import "@voltz-protocol/products-dated-irs/src/modules/MarketConfigurationModule.sol";
import "@voltz-protocol/products-dated-irs/src/modules/OwnerUpgradeModule.sol";
import "@voltz-protocol/products-dated-irs/src/modules/ProductIRSModule.sol";
import "@voltz-protocol/products-dated-irs/src/modules/RateOracleModule.sol";

import "@voltz-protocol/products-dated-irs/src/oracles/AaveV3RateOracle.sol";
import "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

contract DatedIrsRouter is
  MarketConfigurationModule, 
  OwnerUpgradeModule,
  ProductIRSModule,
  RateOracleModule
{}

contract DatedIrsProxy is
  UUPSProxyWithOwner,
  DatedIrsRouter
{ 
  // solhint-disable-next-line no-empty-blocks
  constructor(address firstImplementation, address initialOwner)
      UUPSProxyWithOwner(firstImplementation, initialOwner)
  {}
}

pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/proxy/UUPSProxyWithOwner.sol";

import "@voltz-protocol/products-dated-irs/src/modules/MarketConfigurationModule.sol";
import "@voltz-protocol/products-dated-irs/src/modules/OwnerUpgradeModule.sol";
import "@voltz-protocol/products-dated-irs/src/modules/ProductIRSModule.sol";
import "@voltz-protocol/products-dated-irs/src/modules/RateOracleManager.sol";

import "@voltz-protocol/products-dated-irs/src/oracles/AaveRateOracle.sol";
import "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

contract DatedIrsRouter is
  MarketConfigurationModule, 
  OwnerUpgradeModule,
  ProductIRSModule,
  RateOracleManager 
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

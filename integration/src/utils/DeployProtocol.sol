pragma solidity >=0.8.19;

import {CoreRouter, CoreProxy, AccountNftRouter, AccessPassConfiguration} from "../../src/proxies/Core.sol";
import {DatedIrsRouter, DatedIrsProxy} from "../../src/proxies/DatedIrs.sol";
import {PeripheryRouter, PeripheryProxy} from "../../src/proxies/Periphery.sol";
import {VammRouter, VammProxy} from "../../src/proxies/Vamm.sol";

import {AccessPassNFT} from "@voltz-protocol/access-pass-nft/src/AccessPassNFT.sol";

import {AaveV3RateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveV3RateOracle.sol";
import {AaveV3BorrowRateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveV3BorrowRateOracle.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

contract DeployProtocol {
  CoreProxy public coreProxy;
  DatedIrsProxy public datedIrsProxy;
  PeripheryProxy public peripheryProxy;
  VammProxy public vammProxy;

  AaveV3RateOracle public aaveV3RateOracle;
  AaveV3BorrowRateOracle public aaveV3BorrowRateOracle;

  constructor(address owner, address tokenAddress) {
    CoreRouter coreRouter = new CoreRouter();
    coreProxy = new CoreProxy(address(coreRouter), address(this));

    AccountNftRouter accountNftRouter = new AccountNftRouter();
    coreProxy.initOrUpgradeNft(
      bytes32("accountNFT"), "voltz-v2-account", "VV2A", "www.voltz.xyz", address(accountNftRouter)
    );

    AccessPassNFT accessPassNft = new AccessPassNFT("name", "symbol");
    coreProxy.configureAccessPass(
      AccessPassConfiguration.Data({
        accessPassNFTAddress: address(accessPassNft)
      })
    );
    
    DatedIrsRouter datedIrsRouter = new DatedIrsRouter();
    datedIrsProxy = new DatedIrsProxy(address(datedIrsRouter), address(this));

    PeripheryRouter peripheryRouter = new PeripheryRouter();
    peripheryProxy = new PeripheryProxy(address(peripheryRouter), address(this));
    
    VammRouter vammRouter = new VammRouter();
    vammProxy = new VammProxy(address(vammRouter), address(this));

    MockAaveLendingPool aaveLendingPool = new MockAaveLendingPool();
    aaveV3RateOracle = new AaveV3RateOracle(aaveLendingPool, tokenAddress);
    aaveV3BorrowRateOracle = new AaveV3BorrowRateOracle(aaveLendingPool, tokenAddress);

    coreProxy.nominateNewOwner(owner);
    datedIrsProxy.nominateNewOwner(owner);
    peripheryProxy.nominateNewOwner(owner);
    vammProxy.nominateNewOwner(owner);
    accessPassNft.transferOwnership(owner);
  }
}
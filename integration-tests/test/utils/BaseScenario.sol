pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import {CoreRouter, CoreProxy, AccountNftRouter, AccountNftProxy} from "../../src/Core.sol";
import {DatedIrsRouter, DatedIrsProxy, AaveRateOracle, MockAaveLendingPool} from "../../src/DatedIrs.sol";
import {PeripheryRouter, PeripheryProxy} from "../../src/Periphery.sol";
import {VammRouter, VammProxy} from "../../src/Vamm.sol";

import "./ERC20Mock.sol";

contract BaseScenario is Test {
  AccountNftProxy accountNftProxy;
  CoreProxy coreProxy;
  DatedIrsProxy datedIrsProxy;
  PeripheryProxy peripheryProxy;
  VammProxy vammProxy;

  ERC20Mock token;

  MockAaveLendingPool aaveLendingPool;
  AaveRateOracle aaveRateOracle;

  uint128 constant feeCollectorAccountId = 999;

  address owner;

  function _setUp() public {
    owner = vm.addr(55555);

    vm.startPrank(owner);

    CoreRouter coreRouter = new CoreRouter();
    coreProxy = new CoreProxy(address(coreRouter), owner);

    AccountNftRouter accountNftRouter = new AccountNftRouter();
    coreProxy.initOrUpgradeNft(
      bytes32("accountNFT"), "voltz-v2-account", "VV2A", "www.voltz.xyz", address(accountNftRouter)
    );
    (address accountNftProxyAddress, ) = coreProxy.getAssociatedSystem(bytes32("accountNFT"));
    accountNftProxy = AccountNftProxy(payable(accountNftProxyAddress));

    DatedIrsRouter datedIrsRouter = new DatedIrsRouter();
    datedIrsProxy = new DatedIrsProxy(address(datedIrsRouter), owner);

    PeripheryRouter peripheryRouter = new PeripheryRouter();
    peripheryProxy = new PeripheryProxy(address(peripheryRouter), owner);
    
    VammRouter vammRouter = new VammRouter();
    vammProxy = new VammProxy(address(vammRouter), owner);

    token = new ERC20Mock();

    aaveLendingPool = new MockAaveLendingPool();
    aaveRateOracle = new AaveRateOracle(aaveLendingPool, address(token));

    coreProxy.createAccount(feeCollectorAccountId);
    coreProxy.addToFeatureFlagAllowlist(bytes32("registerProduct"), owner);
    coreProxy.setPeriphery(address(peripheryProxy));

    vm.stopPrank();
  }
}
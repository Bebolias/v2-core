pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import {CoreRouter, CoreProxy, AccountNftRouter, AccountNftProxy, AccessPassConfiguration, IAccessPassNFT} from "../../src/Core.sol";
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
  uint256 constant accessPassTokenId = 1;
  address constant accessPassAddress = address(1111);

  bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";
  bytes32 private constant _CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
  bytes32 private constant _NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG = "notifyAccountTransfer";

  address owner;

  function _setUp() public {
    vm.warp(1687525420);

    owner = vm.addr(55555);

    vm.startPrank(owner);

    CoreRouter coreRouter = new CoreRouter();
    coreProxy = new CoreProxy(address(coreRouter), owner);
    coreProxy.setFeatureFlagAllowAll(_GLOBAL_FEATURE_FLAG, true);
    coreProxy.setFeatureFlagAllowAll(_CREATE_ACCOUNT_FEATURE_FLAG, true);
    coreProxy.setFeatureFlagAllowAll(_NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG, true);


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

    coreProxy.configureAccessPass(
      AccessPassConfiguration.Data(
        {
          accessPassNFTAddress: accessPassAddress
        }
      )
    );

    vm.mockCall(
      accessPassAddress,
      abi.encodeWithSelector(IAccessPassNFT.ownerOf.selector, accessPassTokenId),
      abi.encode(msg.sender)
    );

    coreProxy.createAccount(feeCollectorAccountId, accessPassTokenId, msg.sender);
    coreProxy.addToFeatureFlagAllowlist(bytes32("registerProduct"), owner);

    coreProxy.setPeriphery(address(peripheryProxy));

    vm.stopPrank();
  }
}
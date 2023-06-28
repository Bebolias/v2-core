pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import {CoreRouter, CoreProxy, AccountNftRouter, AccountNftProxy, AccessPassConfiguration} from "../../src/Core.sol";
import {DatedIrsRouter, DatedIrsProxy, AaveRateOracle, MockAaveLendingPool} from "../../src/DatedIrs.sol";
import {PeripheryRouter, PeripheryProxy} from "../../src/Periphery.sol";
import {VammRouter, VammProxy} from "../../src/Vamm.sol";

import {AccessPassNFT} from "@voltz-protocol/access-pass-nft/src/AccessPassNFT.sol";
import {Merkle} from "murky/Merkle.sol";
import {SetUtil} from "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";

import "./ERC20Mock.sol";

contract BaseScenario is Test {
  AccountNftProxy accountNftProxy;
  CoreProxy coreProxy;
  DatedIrsProxy datedIrsProxy;
  PeripheryProxy peripheryProxy;
  VammProxy vammProxy;

  AccessPassNFT accessPassNft;
  Merkle merkle;
  SetUtil.Bytes32Set addressPassNftInfo;
  using SetUtil for SetUtil.Bytes32Set;

  ERC20Mock token;

  MockAaveLendingPool aaveLendingPool;
  AaveRateOracle aaveRateOracle;

  uint128 constant feeCollectorAccountId = 999;

  bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";
  bytes32 private constant _CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
  bytes32 private constant _NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG = "notifyAccountTransfer";

  address owner;

  function _setUp() public {
    vm.warp(1687525420);
    addressPassNftInfo.add(keccak256(abi.encodePacked(address(0), uint256(0))));

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

    coreProxy.addToFeatureFlagAllowlist(bytes32("registerProduct"), owner);

    coreProxy.setPeriphery(address(peripheryProxy));

    peripheryProxy.configure(
      Config.Data({
        WETH9: IWETH9(address(874392112)),  // todo: deploy weth9 mock
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy)
      })
    );

    merkle = new Merkle();

    accessPassNft = new AccessPassNFT("name", "symbol");
    coreProxy.configureAccessPass(
      AccessPassConfiguration.Data({
        accessPassNFTAddress: address(accessPassNft)
      })
    );

    addressPassNftInfo.add(keccak256(abi.encodePacked(owner, uint256(1))));
    accessPassNft.addNewRoot(
      AccessPassNFT.RootInfo({
        merkleRoot: merkle.getRoot(addressPassNftInfo.values()),
        baseMetadataURI: "ipfs://"
      })
    );
    accessPassNft.redeem(
      owner,
      1,
      merkle.getProof(addressPassNftInfo.values(), addressPassNftInfo.length()-1),
      merkle.getRoot(addressPassNftInfo.values())
    );

    bytes memory commands = abi.encodePacked(
      bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT))
    );
    bytes[] memory inputs = new bytes[](1);
    inputs[0] = abi.encode(feeCollectorAccountId);
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    vm.stopPrank();
  }
}
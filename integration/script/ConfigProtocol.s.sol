pragma solidity >=0.8.19;

import "../src/utils/SetupProtocol.sol";

import {Merkle} from "murky/Merkle.sol";
import {SetUtil} from "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";

import {uUNIT as uWAD} from "@prb/math/UD60x18.sol";

contract ConfigProtocol is SetupProtocol {  
  using SetUtil for SetUtil.Bytes32Set;

  SetUtil.Bytes32Set private addressPassNftInfo;
  Merkle private merkle = new Merkle();

  bool private _multisig = vm.envBool("MULTISIG");

  constructor() 
    SetupProtocol(
      SetupProtocol.Contracts({
        coreProxy: CoreProxy(payable(vm.envAddress("CORE_PROXY"))),
        datedIrsProxy: DatedIrsProxy(payable(vm.envAddress("DATED_IRS_PROXY"))),
        peripheryProxy: PeripheryProxy(payable(vm.envAddress("PERIPHERY_PROXY"))),
        vammProxy: VammProxy(payable(vm.envAddress("VAMM_PROXY"))),
        aaveV3RateOracle: AaveV3RateOracle(vm.envAddress("AAVE_V3_RATE_ORACLE")),
        aaveV3BorrowRateOracle: AaveV3BorrowRateOracle(vm.envAddress("AAVE_V3_BORROW_RATE_ORACLE"))
      }),
      SetupProtocol.Settings({
        multisig: _multisig,
        multisigAddress: (_multisig) ? vm.envAddress("MULTISIG_ADDRESS") : address(0),
        multisigSend: (_multisig) ? vm.envBool("MULTISIG_SEND") : false,
        echidna: false,
        broadcast: !_multisig
      }),
      vm.envAddress("OWNER")
    )
  {}

  function run() public {
    // Populate with transactions

    // todo: double check if we also configure
    // ACCESS_PASS_NFT=0xf28E795B214230ba192f7f9167d6CbEc2558B00c
    // AAVE_V3_RATE_ORACLE=0x4072356632230f14385c28e9143fb1c34096bddb
    // AAVE_V3_BORROW_RATE_ORACLE=0xb792a53a24F313CcF3eBF9A51C7eF4aF216b6D4E

    upgradeProxy(address(contracts.coreProxy), address(0x6BB334e672729b63AA7d7c4867D4EbD3f9444Ca3));
    upgradeProxy(address(contracts.datedIrsProxy), address(0xcc22e3862D13f40142C1Ccd9294e8AD66f845bE2));
    upgradeProxy(address(contracts.peripheryProxy), address(0x7917ADcd534c78f6901fc8A07d3834b9b47EAf26));
    upgradeProxy(address(contracts.vammProxy), address(0x1d45dDD16ba18fEE069Adcd85827E71FcD54fc38));

    enableFeatures();

    configureProtocol({
      imMultiplier: ud60x18(1.5e18),
      liquidatorRewardParameter: ud60x18(0.05e18),
      feeCollectorAccountId: 999
    });

    registerDatedIrsProduct(1);

    configureMarket({
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      // note, let's keep as bridged usdc for now
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),  // todo: update helper function if we want native USDC
      productId: 1,
      marketId: 1,
      feeCollectorAccountId: 999,
      liquidationBooster: 0,
      cap: 100000e6,
      atomicMakerFee: ud60x18(0),
      atomicTakerFee: ud60x18(0.0002e18),
      riskParameter: ud60x18(0.013e18),
      twapLookbackWindow: 259200,
      maturityIndexCachingWindowInSeconds: 3600
    });
    uint32[] memory times = new uint32[](2);
     times[0] = uint32(block.timestamp - 86400*4); // note goes back 4 days, while lookback is 3 days, so should be fine?
     times[1] = uint32(block.timestamp - 86400*3);
    int24[] memory observedTicks = new int24[](2);
     observedTicks[0] = -12500; // 3.4% note worth double checking
     observedTicks[1] = -12500; // 3.4%
    deployPool({
      marketId: 1,
      maturityTimestamp: 1692356400,                                // Fri Aug 18 2023 11:00:00 GMT+0000
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      priceImpactPhi: ud60x18(0),
      priceImpactBeta: ud60x18(0),
      spread: ud60x18(0.001e18),
      initTick: -12500, // 3.4%
      tickSpacing: 60,
      // todo: note, is this sufficient, or should we increase? what's the min gap between consecutive observations?
      observationCardinalityNext: 20,
      makerPositionsPerAccountLimit: 1,
      times: times,
      observedTicks: observedTicks
    });
    // todo: note, is this pcv?
    mintOrBurn({
      marketId: 1,
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),
      accountId: 0,
      maturityTimestamp: 1692356400,
      marginAmount: 25000e6,
      notionalAmount: 25000e6 * 500,
      tickLower: -15400, // 4.66% note worth double checking
      tickUpper: -8600, // 2.36% note worth double checking
      rateOracleAddress: address(contracts.aaveV3RateOracle)
    });

    execute_multisig_batch();
  }

  function configure_protocol() public {
    // upgradeProxy(address(contracts.coreProxy), address(0));
    // upgradeProxy(address(contracts.datedIrsProxy), address(0));
    // upgradeProxy(address(contracts.peripheryProxy), address(0));
    // upgradeProxy(address(contracts.vammProxy), address(0));

    acceptOwnerships();
    enableFeatures();
    configureProtocol({
      imMultiplier: ud60x18(2e18),
      liquidatorRewardParameter: ud60x18(5e16),
      feeCollectorAccountId: 999
    });
    registerDatedIrsProduct(1);
    configureMarket({
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),
      productId: 1,
      marketId: 1,
      feeCollectorAccountId: 999,
      liquidationBooster: 1e6,
      cap: 1000e6,
      atomicMakerFee: ud60x18(1e16),
      atomicTakerFee: ud60x18(5e16),
      riskParameter: ud60x18(1e18),
      twapLookbackWindow: 120,
      maturityIndexCachingWindowInSeconds: 3600
    });
    uint32[] memory times = new uint32[](2);
    times[0] = uint32(block.timestamp - 86400);
    times[1] = uint32(block.timestamp - 43200);
    int24[] memory observedTicks = new int24[](2);
    observedTicks[0] = -13860;
    observedTicks[1] = -13860;
    deployPool({
      marketId: 1,
      maturityTimestamp: 1688990400,
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      priceImpactPhi: ud60x18(1e17), // 0.1
      priceImpactBeta: ud60x18(125e15), // 0.125
      spread: ud60x18(3e15), // 0.3%
      initTick: -13860, // price = 4%
      tickSpacing: 60,
      observationCardinalityNext: 16,
      makerPositionsPerAccountLimit: 1,
      times: times,
      observedTicks: observedTicks
    });
    mintOrBurn({
      marketId: 1,
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),
      accountId: 123,
      maturityTimestamp: 1688990400,
      marginAmount: 10e6,
      notionalAmount: 100e6,
      tickLower: -14100, // 4.1%
      tickUpper: -13620, // 3.9%
      rateOracleAddress: address(contracts.aaveV3RateOracle)
    });

    execute_multisig_batch();
  }

  /// @notice this should only be used for testnet (for mainnet
  /// it should be done through cannon)
  function addNewRoot(address[] memory accountOwners, string memory baseMetadataURI) public {
    addressPassNftInfo.add(keccak256(abi.encodePacked(address(0), uint256(0))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(address(metadata.owner), uint256(1))));
    for (uint256 i = 0; i < accountOwners.length; i += 1) {
      bytes32 leaf = keccak256(abi.encodePacked(accountOwners[i], uint256(1)));
      if (!addressPassNftInfo.contains(leaf)) {
        addressPassNftInfo.add(leaf);
      }
    }
    
    addNewRoot(
      AccessPassNFT.RootInfo({
        merkleRoot: merkle.getRoot(addressPassNftInfo.values()),
        baseMetadataURI: baseMetadataURI
      })
    );
  }
}
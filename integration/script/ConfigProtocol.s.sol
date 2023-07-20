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
        broadcast: !_multisig,
        prank: false
      }),
      vm.envAddress("OWNER")
    )
  {}

  function run() public {
    // Populate with transactions

    upgradeProxy(address(contracts.coreProxy), 0x44E1D5aEcb7B4d191F37f1933A30343046bD9ADB);
    upgradeProxy(address(contracts.datedIrsProxy), 0x2463Db784786e04d266d9D91E77E1Fd650204fDD);
    upgradeProxy(address(contracts.peripheryProxy), 0x2457D958DBEBaCc9daA41B47592faCA5845f8Fc3);
    upgradeProxy(address(contracts.vammProxy), 0x8b6663217C62D5510F191de84d1c3a403D304016);

    initOrUpgradeNft({
      id: 0x6163636f756e744e465400000000000000000000000000000000000000000000,
      name: "Voltz V2 Account NFT", 
      symbol: "VOLTZ", 
      uri: "https://www.voltz.xyz/", 
      impl: 0x935b397d9888C70027eCF8F7Dc6a68AbdCceBEd4
    });

    address[] memory pausers = new address[](4);
      pausers[0] = 0x140d001689979ee77C2FB4c8d4B5F3E209135776;
      pausers[1] = 0xA73d7b822Bfad43500a26aC38956dfEaBD3E066d;
      pausers[2] = 0x4a02c244dCED6797d864B408F646Afe470147159;
      pausers[3] = 0xf94e5Cdf41247E268d4847C30A0DC2893B33e85d;
    enableFeatureFlags({
      pausers: pausers
    });

    configureProtocol({
      imMultiplier: ud60x18(1.5e18),
      liquidatorRewardParameter: ud60x18(0.05e18),
      feeCollectorAccountId: 999
    });

    registerDatedIrsProduct(1);

    configureMarket({
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      // note, let's keep as bridged usdc for now
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),
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
     observedTicks[0] = -12240; // 3.4% note worth double checking
     observedTicks[1] = -12240; // 3.4%
    deployPool({
      immutableConfig: VammConfiguration.Immutable({
        maturityTimestamp: 1692356400,                                // Fri Aug 18 2023 11:00:00 GMT+0000
        _maxLiquidityPerTick: type(uint128).max,
        _tickSpacing: 60,
        marketId: 1
      }),
      mutableConfig: VammConfiguration.Mutable({
        priceImpactPhi: ud60x18(0),
        priceImpactBeta: ud60x18(0),
        spread: ud60x18(0.001e18),
        rateOracle: IRateOracle(address(contracts.aaveV3RateOracle)),
        minTick: -15780,  // 4.85%
        maxTick: 15780    // 0.2%
      }),
      initTick: -12240, // 3.4%
      // todo: note, is this sufficient, or should we increase? what's the min gap between consecutive observations?
      observationCardinalityNext: 20,
      makerPositionsPerAccountLimit: 1,
      times: times,
      observedTicks: observedTicks
    });
    mintOrBurn(MintOrBurnParams({
      marketId: 1,
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),
      accountId: 444,
      maturityTimestamp: 1692356400,
      marginAmount: 25000e6,
      notionalAmount: 25000e6 * 500,
      tickLower: -15420, // 4.67%
      tickUpper: -8580, // 2.35%
      rateOracleAddress: address(contracts.aaveV3RateOracle)
    }));

    execute_multisig_batch();
  }

  function configure_protocol() public {
    // upgradeProxy(address(contracts.coreProxy), address(0));
    // upgradeProxy(address(contracts.datedIrsProxy), address(0));
    // upgradeProxy(address(contracts.peripheryProxy), address(0));
    // upgradeProxy(address(contracts.vammProxy), address(0));

    acceptOwnerships();

    address[] memory pausers = new address[](0);
    enableFeatureFlags({
      pausers: pausers
    });
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
      immutableConfig: VammConfiguration.Immutable({
        maturityTimestamp: 1688990400,
        _maxLiquidityPerTick: type(uint128).max,
        _tickSpacing: 60,
        marketId: 1
      }),
      mutableConfig: VammConfiguration.Mutable({
        priceImpactPhi: ud60x18(1e17), // 0.1
        priceImpactBeta: ud60x18(125e15), // 0.125
        spread: ud60x18(3e15), // 0.3%
        rateOracle: IRateOracle(address(contracts.aaveV3RateOracle)),
        minTick: TickMath.DEFAULT_MIN_TICK,
        maxTick: TickMath.DEFAULT_MAX_TICK
      }),
      initTick: -13860, // price = 4%
      observationCardinalityNext: 16,
      makerPositionsPerAccountLimit: 1,
      times: times,
      observedTicks: observedTicks
    });
    mintOrBurn(MintOrBurnParams({
      marketId: 1,
      tokenAddress: Utils.getUSDCAddress(metadata.chainId),
      accountId: 123,
      maturityTimestamp: 1688990400,
      marginAmount: 10e6,
      notionalAmount: 100e6,
      tickLower: -14100, // 4.1%
      tickUpper: -13620, // 3.9%
      rateOracleAddress: address(contracts.aaveV3RateOracle)
    }));

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
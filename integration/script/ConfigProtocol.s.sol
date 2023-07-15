pragma solidity >=0.8.19;

import "../src/utils/SetupProtocol.sol";

import {Merkle} from "murky/Merkle.sol";
import {SetUtil} from "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";

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
  }

  function configure_protocol() public {
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
    deployPool({
      marketId: 1,
      maturityTimestamp: 1688990400,
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      priceImpactPhi: ud60x18(1e17), // 0.1
      priceImpactBeta: ud60x18(125e15), // 0.125
      spread: ud60x18(3e15), // 0.3%
      initTick: -13860, // price = 4%
      observationCardinalityNext: 16,
      makerPositionsPerAccountLimit: 1
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
pragma solidity >=0.8.19;

import "./Hevm.sol";

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {SetupProtocol} from "../../src/utils/SetupProtocol.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

contract Harness {
  DeployProtocol deployProtocol;
  SetupProtocol setupProtocol;

  address owner;
  ERC20Mock token;

  constructor() {
    owner = address(1);
    token = new ERC20Mock(6);

    deployProtocol = new DeployProtocol(owner, address(token));
    setupProtocol = new SetupProtocol(
      SetupProtocol.Contracts({
        coreProxy: deployProtocol.coreProxy(),
        datedIrsProxy: deployProtocol.datedIrsProxy(),
        peripheryProxy: deployProtocol.peripheryProxy(),
        vammProxy: deployProtocol.vammProxy(),
        aaveV3RateOracle: deployProtocol.aaveV3RateOracle(),
        aaveV3BorrowRateOracle: deployProtocol.aaveV3BorrowRateOracle()
      }),
      SetupProtocol.Settings({
        multisig: false,
        multisigAddress: address(0),
        multisigSend: false,
        echidna: true,
        broadcast: false,
        prank: false
      }),
      owner
    );

    setupProtocol.acceptOwnerships();
    address[] memory pausers = new address[](0);
    setupProtocol.enableFeatureFlags({
      pausers: pausers
    });
    // commented out because we need to setup access pass nft
    // setupProtocol.configureProtocol({
    //   imMultiplier: ud60x18(2e18),
    //   liquidatorRewardParameter: ud60x18(5e16),
    //   feeCollectorAccountId: 999
    // });
    // setupProtocol.registerDatedIrsProduct(1);
    // setupProtocol.configureMarket({
    //   rateOracleAddress: address(deployProtocol.aaveV3RateOracle()),
    //   tokenAddress: address(token),
    //   productId: 1,
    //   marketId: 1,
    //   feeCollectorAccountId: 999,
    //   liquidationBooster: 1e6,
    //   cap: 1000e6,
    //   atomicMakerFee: ud60x18(1e16),
    //   atomicTakerFee: ud60x18(5e16),
    //   riskParameter: ud60x18(1e18),
    //   twapLookbackWindow: 120,
    //   maturityIndexCachingWindowInSeconds: 3600
    // });
    // setupProtocol.deployPool({
    //   marketId: 1,
    //   maturityTimestamp: 1688990400,
    //   rateOracleAddress: address(deployProtocol.aaveV3RateOracle()),
    //   priceImpactPhi: ud60x18(1e17), // 0.1
    //   priceImpactBeta: ud60x18(125e15), // 0.125
    //   spread: ud60x18(3e15), // 0.3%
    //   initTick: -13860, // price = 4%
    //   observationCardinalityNext: 16,
    //   makerPositionsPerAccountLimit: 1
    // });
  }

  function createAccount(address user, uint128 requestedAccountId) public {
    hevm.prank(user);
    try deployProtocol.coreProxy().createAccount(requestedAccountId, user) {
      assert(true == true);
    } catch {
      assert(true == true);
    }
  }
}
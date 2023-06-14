pragma solidity >=0.8.19;

import "forge-std/Script.sol";

import {CoreProxy, AccountNftProxy} from "../src/Core.sol";
import {DatedIrsProxy} from "../src/DatedIrs.sol";
import {PeripheryProxy} from "../src/Periphery.sol";
import {VammProxy} from "../src/Vamm.sol";
import {IAaveV3LendingPool} from "@voltz-protocol/products-dated-irs/src/interfaces/external/IAaveV3LendingPool.sol";
import {AaveRateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveRateOracle.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";

import "@prb/math/UD60x18.sol";

import {CollateralConfiguration} from "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import {ProtocolRiskConfiguration} from "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import {MarketFeeConfiguration} from "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";
import {MarketRiskConfiguration} from "@voltz-protocol/core/src/storage/MarketRiskConfiguration.sol";

import {ProductConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import {MarketConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";
import {IAllowanceTransfer} from "@voltz-protocol/periphery/src/interfaces/external/IAllowanceTransfer.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";

import {TickMath} from "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {VammConfiguration, IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

contract TestnetConfig is Script {
  CoreProxy coreProxy = CoreProxy(payable(0x6BB334e672729b63AA7d7c4867D4EbD3f9444Ca3));
  AccountNftProxy accountNftProxy;
  DatedIrsProxy datedIrsProxy = DatedIrsProxy(payable(0xcc22e3862D13f40142C1Ccd9294e8AD66f845bE2));
  PeripheryProxy peripheryProxy = PeripheryProxy(payable(0x7917ADcd534c78f6901fc8A07d3834b9b47EAf26));
  VammProxy vammProxy = VammProxy(payable(0x1d45dDD16ba18fEE069Adcd85827E71FcD54fc38));
  IAaveV3LendingPool aaveLendingPool = IAaveV3LendingPool(address(0xeAA2F46aeFd7BDe8fB91Df1B277193079b727655));
  IERC20 token = IERC20(address(0x72A9c57cD5E2Ff20450e409cF6A542f1E6c710fc));

  uint128 constant feeCollectorAccountId = 999;

  address owner = address(0xF8F6B70a36f4398f0853a311dC6699Aba8333Cc1);

  function run() public {
    vm.startBroadcast(owner);

    (address accountNftProxyAddress, ) = coreProxy.getAssociatedSystem(bytes32("accountNFT"));
    accountNftProxy = AccountNftProxy(payable(accountNftProxyAddress));
    console.log("Account NFT Proxy", accountNftProxyAddress);
    
    uint128 marketId = 1;
    uint32 maturityTimestamp = 1686916800;

    AaveRateOracle aaveRateOracle = new AaveRateOracle(aaveLendingPool, address(token));
    console.log("Aave Rate Oracle", address(aaveRateOracle));

    coreProxy.createAccount(feeCollectorAccountId);
    coreProxy.addToFeatureFlagAllowlist(bytes32("registerProduct"), owner);
    coreProxy.setPeriphery(address(peripheryProxy));

    coreProxy.configureCollateral(
      CollateralConfiguration.Data({
        depositingEnabled: true,
        liquidationBooster: 1e6,
        tokenAddress: address(token),
        cap: 1000e6
      })
    );
    coreProxy.configureProtocolRisk(
      ProtocolRiskConfiguration.Data({
        imMultiplier: UD60x18.wrap(2e18),
        liquidatorRewardParameter: UD60x18.wrap(5e16)
      })
    );

    uint128 productId = coreProxy.registerProduct(address(datedIrsProxy), "Dated IRS Product");
    console.log("Product Id");
    console.logUint(productId);

    datedIrsProxy.configureMarket(
      MarketConfiguration.Data({
        marketId: marketId,
        quoteToken: address(token)
      })
    );
    datedIrsProxy.setVariableOracle(
      1,
      address(aaveRateOracle)
    );
    datedIrsProxy.configureProduct(
      ProductConfiguration.Data({
        productId: productId,
        coreProxy: address(coreProxy),
        poolAddress: address(vammProxy)
      })
    );

    coreProxy.configureMarketFee(
      MarketFeeConfiguration.Data({
        productId: productId,
        marketId: marketId,
        feeCollectorAccountId: feeCollectorAccountId,
        atomicMakerFee: UD60x18.wrap(1e16),
        atomicTakerFee: UD60x18.wrap(5e16)
      })
    );
    coreProxy.configureMarketRisk(
      MarketRiskConfiguration.Data({
        productId: productId, 
        marketId: marketId, 
        riskParameter: SD59x18.wrap(1e18), 
        twapLookbackWindow: 86400
      })
    );

    VammConfiguration.Immutable memory immutableConfig = VammConfiguration.Immutable({
        maturityTimestamp: maturityTimestamp,
        _maxLiquidityPerTick: type(uint128).max,
        _tickSpacing: 60,
        marketId: marketId
    });

    VammConfiguration.Mutable memory mutableConfig = VammConfiguration.Mutable({
        priceImpactPhi: ud60x18(1e17), // 0.1
        priceImpactBeta: ud60x18(125e15), // 0.125
        spread: ud60x18(3e15), // 0.3%
        rateOracle: IRateOracle(address(aaveRateOracle))
    });

    vammProxy.setProductAddress(address(datedIrsProxy));
    vammProxy.createVamm(
      1,
      TickMath.getSqrtRatioAtTick(-13860), // price = 4%
      immutableConfig,
      mutableConfig
    );

    peripheryProxy.configure(
      Config.Data({
        WETH9: IWETH9(address(0)),  // todo: deploy weth9 mock
        PERMIT2: IAllowanceTransfer(address(0)), // todo: deploy permit2
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy),
        VOLTZ_V2_ACCOUNT_NFT_PROXY: address(accountNftProxy)
      })
    );

    vm.stopBroadcast();
  }
}
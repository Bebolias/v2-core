pragma solidity >=0.8.19;

import "./utils/BaseScenario.sol";

import "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";

import "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";

import "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {ExtendedPoolModule} from "@voltz-protocol/v2-vamm/test/PoolModule.t.sol";
import {VammConfiguration, IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import { ud60x18, div } from "@prb/math/UD60x18.sol";

contract Scenario1 is BaseScenario {
  uint128 productId;
  uint128 marketId;
  uint32 maturityTimestamp;
  ExtendedPoolModule extendedPoolModule; // used to convert base to liquidity :)

  function setUp() public {
    super._setUp();
    marketId = 1;
    maturityTimestamp = uint32(block.timestamp) + 259200;
    extendedPoolModule = new ExtendedPoolModule();
  }

  function setConfigs() public {
    vm.startPrank(owner);

    coreProxy.configureCollateral(
      CollateralConfiguration.Data({
        depositingEnabled: true,
        liquidationBooster: 1e18,
        tokenAddress: address(token),
        cap: 1000000e18
      })
    );
    coreProxy.configureProtocolRisk(
      ProtocolRiskConfiguration.Data({
        imMultiplier: UD60x18.wrap(2e18),
        liquidatorRewardParameter: UD60x18.wrap(5e16)
      })
    );

    productId = coreProxy.registerProduct(address(datedIrsProxy), "Dated IRS Product");

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
        twapLookbackWindow: 120
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
      marketId,
      TickMath.getSqrtRatioAtTick(-13860), // price = 4%
      immutableConfig,
      mutableConfig
    );
    vammProxy.increaseObservationCardinalityNext(marketId, maturityTimestamp, 16);

    peripheryProxy.configure(
      Config.Data({
        WETH9: IWETH9(address(874392112)),  // todo: deploy weth9 mock
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy),
        VOLTZ_V2_ACCOUNT_NFT_PROXY: address(accountNftProxy)
      })
    );

    vm.stopPrank();

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(1e18));
  }

  function test() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);

    vm.warp(block.timestamp + 43200); // advance by 0.5 days

    token.mint(user1, 1001e18);

    token.approve(address(peripheryProxy), 1001e18);

    vm.clearMockedCalls();

    vm.mockCall(
      accessPassAddress,
      abi.encodeWithSelector(IAccessPassNFT.ownerOf.selector, accessPassTokenId),
      abi.encode(user1)
    );

    bytes memory commands = abi.encodePacked(
      bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
      bytes1(uint8(Commands.TRANSFER_FROM)),
      bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
    );
    bytes[] memory inputs = new bytes[](4);
    inputs[0] = abi.encode(1, accessPassTokenId);
    inputs[1] = abi.encode(address(token), 1001e18);
    inputs[2] = abi.encode(1, address(token), 1000e18);
    inputs[3] = abi.encode(
      1,  // accountId
      marketId,
      maturityTimestamp,
      -14100, // 4.1%
      -13620, // 3.9% 
      extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18)    
    );
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    vm.stopPrank();

    vm.warp(block.timestamp + 43200); // advance by 0.5 days

    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 501e18);

    token.approve(address(peripheryProxy), 501e18);

    vm.clearMockedCalls();

    vm.mockCall(
      accessPassAddress,
      abi.encodeWithSelector(IAccessPassNFT.ownerOf.selector, accessPassTokenId),
      abi.encode(user2)
    );

    commands = abi.encodePacked(
      bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
      bytes1(uint8(Commands.TRANSFER_FROM)),
      bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
    );
    inputs = new bytes[](4);
    inputs[0] = abi.encode(2, accessPassTokenId);
    inputs[1] = abi.encode(address(token), 501e18);
    inputs[2] = abi.encode(2, address(token), 500e18);
    inputs[3] = abi.encode(
      2,  // accountId
      marketId,
      maturityTimestamp,
      500e18,
      TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK + 1)
    );
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(101e16));

    uint256 traderExposure = div(ud60x18(500e18 * 2 * 1.01), ud60x18(365 * 1e18)).unwrap();
    uint256 eps = 1000; // 1e-15 * 1e18

    assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, -int256(traderExposure - eps));
    assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, -int256(traderExposure + eps));

    assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, int256(traderExposure - eps));
    assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, int256(traderExposure + eps));
  }
}
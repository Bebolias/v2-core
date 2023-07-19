pragma solidity >=0.8.19;

import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

contract Scenario_FixedRate is ScenarioHelper {
  uint32 maturityTimestamp = 1704110400;                                              // Mon Jan 01 2024 12:00:00 GMT+0000
  uint128 marketId = 1;

  LpActor lp = LpActor({
    walletAddress: vm.addr(1_001),
    accountId: 1_001,
    tickLower: -38040, // 44.87%
    tickUpper: -13860 // 3.998%
  });

  TraderActor vt = TraderActor({
    walletAddress: vm.addr(2_001),
    accountId: 2_001 
  });

  function setUpAccessPassNftAndRedeemAll() internal {
    address[] memory accessPassOwners = new address[](3);
    accessPassOwners[0] = owner;
    accessPassOwners[1] = lp.walletAddress;
    accessPassOwners[2] = vt.walletAddress;

    setUpAccessPassNft(accessPassOwners);
    for (uint256 i = 0; i < accessPassOwners.length; i += 1) {
      redeemAccessPass(accessPassOwners[i], 1, i);
    } 
  }

  function setUp() public {
    vm.warp(1672574400);                                                              // Sun Jan 01 2023 12:00:00 GMT+0000

    setUpAccessPassNftAndRedeemAll();

    acceptOwnerships();
    enableFeatures();
    configureProtocol({
      imMultiplier: ud60x18(1.5e18),
      liquidatorRewardParameter: ud60x18(0.05e18),
      feeCollectorAccountId: 999
    });
    registerDatedIrsProduct(1);
    configureMarket({
      rateOracleAddress: address(contracts.aaveV3RateOracle),
      tokenAddress: address(token),
      productId: 1,
      marketId: marketId,
      feeCollectorAccountId: 999,
      liquidationBooster: 0,
      cap: 100000e6,
      atomicMakerFee: ud60x18(0),
      atomicTakerFee: ud60x18(0),
      riskParameter: ud60x18(0.013e18),
      twapLookbackWindow: 259200,
      maturityIndexCachingWindowInSeconds: 3600
    }); 
    uint32[] memory times = new uint32[](2);
    times[0] = uint32(block.timestamp - 86400*4);
    times[1] = uint32(block.timestamp - 86400*3);
    int24[] memory observedTicks = new int24[](2);
    observedTicks[0] = -13863;
    observedTicks[1] = -13863;
    deployPool({
      immutableConfig: VammConfiguration.Immutable({
          maturityTimestamp: maturityTimestamp, // Fri Aug 18 2023 11:00:00 GMT+0000
          _maxLiquidityPerTick: type(uint128).max,
          _tickSpacing: 60,
          marketId: marketId
      }),
      mutableConfig: VammConfiguration.Mutable({
          priceImpactPhi: ud60x18(0),
          priceImpactBeta: ud60x18(0),
          spread: ud60x18(0),
          rateOracle: IRateOracle(address(contracts.aaveV3RateOracle)),
          minTick: -39120,  // 50%
          maxTick: 39120    // 0.02%
      }),
      initTick: -13860, // 3.998%
      observationCardinalityNext: 8760,
      makerPositionsPerAccountLimit: 1,
      times: times,
      observedTicks: observedTicks
    });

    MockAaveLendingPool(
      address(contracts.aaveV3RateOracle.aaveLendingPool())
    ).setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18));

    token.mint(lp.walletAddress, 1000e6);
    token.mint(vt.walletAddress, 1000e6);
  }

  function mintLp() internal {
    executeMakerOrder({
        _marketId: marketId,
        _maturityTimestamp: maturityTimestamp,
        accountId: lp.accountId,
        user: lp.walletAddress,
        count: 0,
        merkleIndex: 0,
        margin: 100e6,
        baseAmount: 100e6 * 5,
        tickLower: lp.tickLower,
        tickUpper: lp.tickUpper
    });
  }

  // Trades VT more than liquidity available (hits min tick)
  function tradeVt() internal {
    executeTakerOrder({
        _marketId: marketId,
        _maturityTimestamp: maturityTimestamp,
        accountId: vt.accountId,
        user: vt.walletAddress,
        count: 0,
        merkleIndex: 0,
        margin: 100e6,
        baseAmount: 100e6 * 5 + 10
    });
  }

  // Unwinds VT more than liquidity available (hits max tick)
  function unwindVt() internal {
    executeTakerOrder({
        _marketId: marketId,
        _maturityTimestamp: maturityTimestamp,
        accountId: vt.accountId,
        user: vt.walletAddress,
        count: 0,
        merkleIndex: 0,
        margin: 100e6,
        baseAmount: -100e6 * 5 - 10
    });
  }

  function test_VammBounds() public {
    mintLp();

    tradeVt();
    assertEq(contracts.vammProxy.getVammTick(marketId, maturityTimestamp), -39120);

    unwindVt();
    assertEq(contracts.vammProxy.getVammTick(marketId, maturityTimestamp), 39120 - 1);
  }

  function test_MarginReqAndUnrealizedLoss_Beginning() public {
    ////////////////////////////////////              LP             ////////////////////////////////////
    // - Abs. Notional Lower = 0 USDC
    // - Abs. Notional Upper = 500 USDC
    // - LM = max(0, 500) USDC * 0.013 = 6.5 USDC
    // - IM = LM * 1.5 = 9.75 USDC
    // - Average Swap Price:  1 / (1.0001 ^ ((-13860 + -38040) / 2)) ~= 13.3948%
    // - Highest Unrealized Loss ~= min(0, 500 USDC * (13.3948% FR - 4% TWAP)) = 0
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    mintLp();
    MarginData memory lpMarginData = getMarginData(lp.accountId);
    assertAlmostEq(lpMarginData.liquidationMarginRequirement, 6.5e6, 10);
    assertAlmostEq(lpMarginData.initialMarginRequirement, 9.75e6, 10);
    assertEq(lpMarginData.highestUnrealizedLoss, 0);

    ////////////////////////////////////              VT             ////////////////////////////////////
    // - Abs. Notional = 500 USDC
    // - LM = 500 USDC * 0.013 = 6.5 USDC
    // - IM = LM * 1.5 = 9.75 USDC
    // - Average Swap Price:  1 / (1.0001 ^ ((-13860 + -38040) / 2)) ~= 13.3948%
    // - Highest Unrealized Loss ~= min(0, 500 USDC * (4% TWAP - 13.3948% FR)) ~= 46.974 USDC
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    tradeVt();
    MarginData memory vtMarginData = getMarginData(vt.accountId);
    assertAlmostEq(vtMarginData.liquidationMarginRequirement, 6.5e6, 10);
    assertAlmostEq(vtMarginData.initialMarginRequirement, 9.75e6, 10);
    assertAlmostEq(vtMarginData.highestUnrealizedLoss, 46.974e6, 0.05e6);

    ////////////////////////////////////              VT             ////////////////////////////////////
    // - Abs. Notional = 0 USDC
    // - LM = 0 USDC * 0.013 = 0 USDC
    // - IM = LM * 1.5 = 0 USDC
    // - Average Swap Price:  1 / (1.0001 ^ ((-13860 + -38040) / 2)) ~= 13.3948%
    // - Highest Unrealized Loss = 0
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    unwindVt();
    vtMarginData = getMarginData(vt.accountId);
    assertEq(vtMarginData.liquidationMarginRequirement, 0);
    assertEq(vtMarginData.initialMarginRequirement, 0);
    assertEq(vtMarginData.highestUnrealizedLoss, 0);
  }
  
  function test_MarginReqAndUnrealizedLoss_HighTwap() public {
    mintLp();

    tradeVt();

    // advance time by 2.5 days
    vm.warp(block.timestamp + 2.5 * 86400);

    // Set Variable APY to 3%
    // 1 * (1 + 0.03)^(2.5/365)
    MockAaveLendingPool(
      address(contracts.aaveV3RateOracle.aaveLendingPool())
    ).setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.0002024780455125e18));

    ////////////////////////////////////              LP             ////////////////////////////////////
    // - Abs. Notional Lower = 0 USDC
    // - Abs. Notional Upper = 500 * 1.0002024780455125 * (365 - 2.5) / 365 
    //                       = 500.101 * (365 - 2.5) / 365 = 496.675 USDC
    // - LM = max(0, 496.675) USDC * 0.013 = 6.456786 USDC
    // - IM = LM * 1.5 = 9.685179 USDC
    // - Average Swap Price:  1 / (1.0001 ^ ((-13860 + -38040) / 2)) ~= 13.3948%
    // - TWAP = (4% * 0.5 days + 49.989% * 2.5 days) / 3 days = 42.32%
    // -      !! avg tick = (-13860 * 0.5 + -39120 * 2.5) / 3 = -34910, TWAP = 32.813% // todo
    // - Highest Unrealized Loss ~= abs(min(0, 496.675 USDC * (13.3948% FR - 32.813% TWAP))) = 96.44534
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    MarginData memory lpMarginData = getMarginData(lp.accountId);
    assertEq(lpMarginData.liquidatable, true);  // todo: check liqui
    assertAlmostEq(lpMarginData.liquidationMarginRequirement, 6.456786e6, 10);
    assertAlmostEq(lpMarginData.initialMarginRequirement, 9.685179e6, 10);
    assertAlmostEq(lpMarginData.highestUnrealizedLoss, 96.44534e6, 0.4e6); // todo
  }

  function test_MarginReqAndUnrealizedLoss_Spike() public {
    mintLp();

    tradeVt();

    // advance time by 3 hours
    vm.warp(block.timestamp + 3 * 3600);

    // Set Variable APY to 3%
    // 1 * (1 + 0.03)^(0.125/365)
    MockAaveLendingPool(
      address(contracts.aaveV3RateOracle.aaveLendingPool())
    ).setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.0000101229287164e18));

    ////////////////////////////////////              LP             ////////////////////////////////////
    // - Abs. Notional Lower = 0 USDC4
    // - Abs. Notional Upper = 500 * 1.0000101229287164 * (365 - 0.125) / 365 
    //                       = 500.005 * (365 - 0.125) / 365 = 499.833 USDC
    // - LM = max(0, 499.833) USDC * 0.013 = 6.497829 USDC
    // - IM = LM * 1.5 = 9.7467435 USDC
    // - Average Swap Price:  1 / (1.0001 ^ ((-13860 + -38040) / 2)) ~= 13.3948%
    // - TWAP = (4% * 2.875 days + 49.989% * 0.125 days) / 3 days = 5.91%
    // -      !! avg tick = (-13860 * 2.875 + -39120 * 0.125) / 3 = -14912, TWAP = 4.442% // todo
    // - Highest Unrealized Loss ~= abs(min(0, 499.833 USDC * (13.3948% FR - 4.4423% TWAP))) = 0
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    MarginData memory lpMarginData = getMarginData(lp.accountId);
    assertEq(lpMarginData.liquidatable, false);
    assertAlmostEq(lpMarginData.liquidationMarginRequirement, 6.497829e6, 10);
    assertAlmostEq(lpMarginData.initialMarginRequirement, 9.746744e6, 15);
    assertEq(lpMarginData.highestUnrealizedLoss, 0);

    ////////////////////////////////////              VT             ////////////////////////////////////
    // - Abs. Notional = 500 * 1.0000101229287164 * (365 - 0.125) / 365 USDC = 499.833 USDC
    // - LM = 499.833 USDC * 0.013 = 6.497829 USDC
    // - IM = LM * 1.5 = 9.7467435 USDC
    // - Average Swap Price:  1 / (1.0001 ^ ((-13860 + -38040) / 2)) ~= 13.3948%
    // - TWAP = (4% * 2.875 days + 49.989% * 0.125 days) / 3 days = 5.91%
    // -      !! avg tick = (-13860 * 2.875 + -39120 * 0.125) / 3 = -14912, TWAP = 4.442% // todo
    // - Highest Unrealized Loss ~= abs(min(0, 499.833 USDC * (4.4423% TWAP - 13.3948% FR))) = 44.7475
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    MarginData memory vtMarginData = getMarginData(vt.accountId);
    assertEq(vtMarginData.liquidatable, false);
    assertAlmostEq(vtMarginData.liquidationMarginRequirement, 6.497829e6, 10);
    assertAlmostEq(vtMarginData.initialMarginRequirement, 9.746744e6, 15);
    assertAlmostEq(vtMarginData.highestUnrealizedLoss, 44.7475e6, 0.05e6);

    // todo: bring rate down and make sure twap is going down
  }
}

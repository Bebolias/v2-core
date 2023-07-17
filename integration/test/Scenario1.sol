pragma solidity >=0.8.19;

import "./utils/BaseScenario.sol";
import "./utils/TestUtils.sol";

import {CollateralConfiguration} from "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import {ProtocolRiskConfiguration} from "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import {MarketFeeConfiguration} from "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";
import {MarketRiskConfiguration} from "@voltz-protocol/core/src/storage/MarketRiskConfiguration.sol";

import {ProductConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import {MarketConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {ExtendedPoolModule} from "@voltz-protocol/v2-vamm/test/PoolModule.t.sol";
import {VammConfiguration, IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import {SafeCastI256, SafeCastU256, SafeCastU128} from "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";

import { ud60x18, div, SD59x18, UD60x18 } from "@prb/math/UD60x18.sol";

contract Scenario1 is BaseScenario, TestUtils {
  using SafeCastI256 for int256;
  using SafeCastU256 for uint256;
  using SafeCastU128 for uint128;

  uint256 internal constant Q96 = 0x1000000000000000000000000;
  uint256 internal constant WAD = 1_000_000_000_000_000_000;

  address internal user1;
  address internal user2;

  uint128 productId;
  uint128 marketId;
  uint32 maturityTimestamp;
  ExtendedPoolModule extendedPoolModule; // used to convert base to liquidity :)

  using SetUtil for SetUtil.Bytes32Set;

  function setUp() public {
    super._setUp();
    user1 = vm.addr(1);
    user2 = vm.addr(2);
    marketId = 1;
    maturityTimestamp = uint32(block.timestamp) + 345600; // in 3 days
    extendedPoolModule = new ExtendedPoolModule();
  }

  function setConfigs() public {
    vm.startPrank(owner);

    coreProxy.configureCollateral(
      CollateralConfiguration.Data({
        depositingEnabled: true,
        liquidationBooster: 0,
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
      address(aaveV3RateOracle),
      3600
    );
    datedIrsProxy.configureProduct(
      ProductConfiguration.Data({
        productId: productId,
        coreProxy: address(coreProxy),
        poolAddress: address(vammProxy),
        takerPositionsPerAccountLimit: 1
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
        riskParameter: UD60x18.wrap(1e18), 
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
        priceImpactPhi: ud60x18(0), // 0
        priceImpactBeta: ud60x18(0), // 0
        spread: ud60x18(3e15), // 0.3%
        rateOracle: IRateOracle(address(aaveV3RateOracle)),
        minTick: TickMath.DEFAULT_MIN_TICK,
        maxTick: TickMath.DEFAULT_MAX_TICK
    });

    vammProxy.setProductAddress(address(datedIrsProxy));
    // make sure the current time > 1 day
    uint32[] memory times = new uint32[](2);
    times[0] = uint32(block.timestamp - 86400);
    times[1] = uint32(block.timestamp - 43200);
    int24[] memory observedTicks = new int24[](2);
    observedTicks[0] = -13860;
    observedTicks[1] = -13860;
    vammProxy.createVamm(
      marketId,
      TickMath.getSqrtRatioAtTick(-13860), // price = 4%
      times,
      observedTicks,
      immutableConfig,
      mutableConfig
    );
    vammProxy.increaseObservationCardinalityNext(marketId, maturityTimestamp, 16);
    vammProxy.setMakerPositionsPerAccountLimit(1);

    peripheryProxy.configure(
      Config.Data({
        WETH9: IWETH9(address(874392112)),  // todo: deploy weth9 mock (AN)
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy)
      })
    );

    vm.stopPrank();

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(1e18));

    // ACCESS PASS
    addressPassNftInfo.add(keccak256(abi.encodePacked(user1, uint256(1))));

    addressPassNftInfo.add(keccak256(abi.encodePacked(user2, uint256(1))));

    vm.startPrank(owner);
    accessPassNft.addNewRoot(
      AccessPassNFT.RootInfo({
        merkleRoot: merkle.getRoot(addressPassNftInfo.values()),
        baseMetadataURI: "ipfs://"
      })
    );
    vm.stopPrank();

    vm.warp(block.timestamp + 43200); // advance by 0.5 days
  }

  function redeemAccessPass(address user, uint256 count, uint256 merkleIndex) public {
    accessPassNft.redeem(
      user,
      count,
      merkle.getProof(addressPassNftInfo.values(), merkleIndex),
      merkle.getRoot(addressPassNftInfo.values())
    );
  }

  function test_MINT_VT() public {
    setConfigs();

    vm.startPrank(user1);

    token.mint(user1, 1001e18);

    token.approve(address(peripheryProxy), 1001e18);

    redeemAccessPass(user1, 1, 2);

    // PERIPHERY LP COMMAND
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
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
    }

    vm.stopPrank();

    vm.startPrank(user2);

    token.mint(user2, 501e18);

    token.approve(address(peripheryProxy), 501e18);

    redeemAccessPass(user2, 1, 3);

    /// PERIPHERY SWAP COMMAND
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(2, address(token), 500e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        500e18,
        0
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(101e16));

    uint256 traderExposure = div(ud60x18(500e18 * 2.5 * 1.01), ud60x18(365 * 1e18)).unwrap();
    uint256 eps = 1000; // 1e-15 * 1e18

    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, -int256(traderExposure - eps));
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, -int256(traderExposure + eps));

    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, int256(traderExposure - eps));
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, int256(traderExposure + eps));

    vm.stopPrank();
  }

  function test_MINT_FT() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);

    token.mint(user1, 1001e18);

    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    int128 lpLiquidity = extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18); // 833_203_486_935_127_427_677_715
    redeemAccessPass(user1, 1, 2);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
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
    }

    vm.stopPrank();

    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 501e18);

    token.approve(address(peripheryProxy), 501e18);

    /// PERIPHERY FT SWAP COMMAND -> tick grows (fixed rate reduces)
    redeemAccessPass(user2, 1, 3);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(2, address(token), 500e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        -500e18,
        0 // todo: compute this properly
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);

      vm.stopPrank();
    }

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp); // -13837 = 3.98%

    uint256 liquidityIndex = 1_010_000_000_000_000_000;
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(101e16));

    // traderExposure = notional * liq index * daysTillMaturity / daysInYear
    uint256 traderExposure = div(ud60x18(500e18 * 2.5 * 1.01), ud60x18(365 * 1e18)).unwrap();

    // notional 10000e18 -> base 10000e18 * 1.01 -> 
    // base long = base between tl & tc = (position.liquidity) / (sqrtHigh - sqrtLow)
    // base short = base between tu & tc
    int256 liquidityTimeFactor = liquidityIndex.toInt() * int256(5) / int256(365 * 2);
    int256 lpUnfilledExposureLong = 
      (
        int256(lpLiquidity) * 
        (uint256(TickMath.getSqrtRatioAtTick(-13620) - TickMath.getSqrtRatioAtTick(currentTick))).toInt()
        / Q96.toInt() 
      )
      * liquidityTimeFactor
      / WAD.toInt();
    int256 lpUnfilledExposureShort = 
      (
        int256(lpLiquidity) * 
        (uint256(TickMath.getSqrtRatioAtTick(currentTick) - TickMath.getSqrtRatioAtTick(-14100))).toInt()
        / Q96.toInt() 
      )
      * liquidityTimeFactor
      / WAD.toInt();
    uint256 eps = 1000; // 1e-15 * 1e18

    // LP
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, int256(traderExposure - eps));
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, int256(traderExposure + eps));
    // assertAlmostEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort,
    //   lpUnfilledExposureShort < 0 ? (-lpUnfilledExposureShort).toUint() : lpUnfilledExposureShort.toUint(),
    //   10000
    // );
    // assertAlmostEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong,
    //   lpUnfilledExposureLong < 0 ? (-lpUnfilledExposureLong).toUint() : lpUnfilledExposureLong.toUint(),
    //   10000
    // );

    // // TRADER
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, -int256(traderExposure - eps));
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, -int256(traderExposure + eps));
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledShort, 0);
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledLong, 0);
  }

  function test_MINT_FT_hit_max_tick() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);
    token.mint(user1, 1001e18);
    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    redeemAccessPass(user1, 1, 2);
    int128 lpLiquidity = extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18); // 833_203_486_935_127_427_677_715
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
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
    }

    vm.stopPrank();
    //uint256 lpUnfilledLongBeforeTrade = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong;

    address user2 = vm.addr(2);
    vm.startPrank(user2);
    token.mint(user2, 10001e18);
    token.approve(address(peripheryProxy), 10001e18);

    /// PERIPHERY FT SWAP COMMAND -> tick grows
    redeemAccessPass(user2, 1, 3);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 10001e18);
      inputs[2] = abi.encode(2, address(token), 10000e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        -10000e18,
        0 // todo: compute this properly
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }
    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp); // 0% 69100
    assertEq(currentTick, 69099);

    uint256 liquidityIndex = 101e16;
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(liquidityIndex));

    // traderExposure = notional * liq index * daysTillMaturity / daysInYear
    //uint256 lpExposureFilledAfter = lpUnfilledLongBeforeTrade * liquidityIndex / WAD;

    // notional 10000e18 -> base 10000e18 * 1.01 -> 
    // base short = base between tl & tu = (position.liquidity) / (sqrtHigh - sqrtLow)
    int256 liquidityTimeFactor = liquidityIndex.toInt() * int256(5) / int256(365 * 2);
    int256 lpUnfilledExposureShort = 
      (
        int256(lpLiquidity) * 
        (uint256(TickMath.getSqrtRatioAtTick(-13620) - TickMath.getSqrtRatioAtTick(-14100))).toInt()
        / Q96.toInt() 
      )
      * liquidityTimeFactor
      / WAD.toInt();
    uint256 eps = 10000; // 1e-14 * 1e18

    // LP
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled,
    //  (lpExposureFilledAfter - eps).toInt(), "f l");
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled,
    // (lpExposureFilledAfter + eps).toInt(), "f l");
    // assertGe(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort,
    //   (lpUnfilledExposureShort < 0 ? (-lpUnfilledExposureShort).toUint() : lpUnfilledExposureShort.toUint()) - eps,
    //   "us l"
    // );
    // assertLe(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort,
    //   (lpUnfilledExposureShort < 0 ? (-lpUnfilledExposureShort).toUint() : lpUnfilledExposureShort.toUint()) + eps,
    //   "us l"
    // );
    // assertEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong,
    //   0
    // );

    // // TRADER
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled,
    // -(lpExposureFilledAfter - eps).toInt(), "f t");
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled,
    // -(lpExposureFilledAfter + eps).toInt(), "f t");
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledShort, 0);
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledLong, 0);
  }

  function test_MINT_VT_hit_min_tick() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);
    token.mint(user1, 1001e18);
    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    redeemAccessPass(user1, 1, 2);
    int128 lpLiquidity = extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18); // 833_203_486_935_127_427_677_715
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
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
    }

    vm.stopPrank();
    //uint256 lpUnfilledShortBeforeTrade = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;

    address user2 = vm.addr(2);
    vm.startPrank(user2);
    token.mint(user2, 10001e18);
    token.approve(address(peripheryProxy), 10001e18);

    /// PERIPHERY VT SWAP COMMAND -> tick grows
    redeemAccessPass(user2, 1, 3);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 10001e18);
      inputs[2] = abi.encode(2, address(token), 10000e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        10000e18,
        0 // todo: compute this properly
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }
    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp); // 1000% -69100
    assertEq(currentTick, -69100);

    uint256 liquidityIndex = 101e16;
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(liquidityIndex));

    // traderExposure = notional * liq index * daysTillMaturity / daysInYear
    //uint256 lpExposureFilledAfter = lpUnfilledShortBeforeTrade * liquidityIndex / WAD; // positive number (abs)

    // notional 10000e18 -> base 10000e18 * 1.01 -> 
    // base short = base between tl & tu = (position.liquidity) / (sqrtHigh - sqrtLow)
    int256 liquidityTimeFactor = liquidityIndex.toInt() * int256(5) / int256(365 * 2);
    int256 lpUnfilledExposureLong = 
      (
        int256(lpLiquidity) * 
        (uint256(TickMath.getSqrtRatioAtTick(-13620) - TickMath.getSqrtRatioAtTick(-14100))).toInt()
        / Q96.toInt() 
      )
      * liquidityTimeFactor
      / WAD.toInt();
    uint256 eps = 10000; // 1e-14 * 1e18

    // LP
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled,
    // -(lpExposureFilledAfter + eps).toInt(), "f l");
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled,
    // -(lpExposureFilledAfter - eps).toInt(), "f l");
    // assertGe(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong,
    //   (lpUnfilledExposureLong < 0 ? (-lpUnfilledExposureLong).toUint() : lpUnfilledExposureLong.toUint()) - eps,
    //   "us l"
    // );
    // assertLe(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong,
    //   (lpUnfilledExposureLong < 0 ? (-lpUnfilledExposureLong).toUint() : lpUnfilledExposureLong.toUint()) + eps,
    //   "us l"
    // );
    // assertEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort,
    //   0
    // );

    // // TRADER
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled,
    // (lpExposureFilledAfter + eps).toInt(), "f t");
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled,
    // (lpExposureFilledAfter - eps).toInt(), "f t");
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledShort, 0);
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledLong, 0);
  }

  // expect completed order to be 0
  function test_MINT_out_of_range_VT() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);
    token.mint(user1, 1001e18);
    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    redeemAccessPass(user1, 1, 2);
    int128 lpLiquidity = extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18); // 833_203_486_935_127_427_677_715
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
      inputs[1] = abi.encode(address(token), 1001e18);
      inputs[2] = abi.encode(1, address(token), 1000e18);
      inputs[3] = abi.encode(
        1,  // accountId
        marketId,
        maturityTimestamp,
        -13620, // 3.9% 
        -13380, // 3.8%
        extendedPoolModule.getLiquidityForBase(-13620, -13380, 10000e18)    
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    vm.stopPrank();
    //uint256 lpUnfilledShortBeforeTrade = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;

    address user2 = vm.addr(2);
    vm.startPrank(user2);
    token.mint(user2, 10001e18);
    token.approve(address(peripheryProxy), 501e18);

    /// PERIPHERY VT SWAP COMMAND -> tick grows
    bytes[] memory swapOutput;
    redeemAccessPass(user2, 1, 3);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(2, address(token), 500e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        500e18,
        0 // todo: compute this properly
      );
      swapOutput = peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }
    int24 currentTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp); // 1000% -69100
    assertEq(currentTickVamm, -69100); 

    (
      int256 executedBaseAmount,
      int256 executedQuoteAmount,
      uint256 fee,
      uint256 im,
      uint256 loss,
      int24 currentTick
    ) = abi.decode(swapOutput[3], (int256, int256, uint256, uint256, uint256, int24));

    assertEq(executedBaseAmount, 0);
    assertEq(executedQuoteAmount, 0);
    assertEq(fee, 0);
    assertEq(currentTick, currentTickVamm);


    uint256 eps = 10000; // 1e-14 * 1e18
    // LP
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, 0, "f l");
    // // TRADER
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, 0, "f t");

    vm.stopPrank();
  }

  function test_Recovery_From_Min_Tick() public {
    /*
    test_MINT_out_of_range_VT description:
      prev tick 5%
      LP 1000e18 base 3.9% 3.8%
      TRADE VT 500e18 base
      curent tick 1000% (min tick)
     */
    test_MINT_out_of_range_VT(); 

    // execute Unwind -> flipping to FT
    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 601e18);

    token.approve(address(peripheryProxy), 601e18);

    /// PERIPHERY FT SWAP COMMAND -> tick grows (fixed rate reduces)
    bytes[] memory swapOutput;
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](3);
      inputs[0] = abi.encode(address(token), 601e18);
      inputs[1] = abi.encode(2, address(token), 600e18);
      inputs[2] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        -600e18,
        0 // todo: compute this properly
      );
      swapOutput = peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    int24 currentTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp);
    assertGe(currentTickVamm, -13860);

    (
      int256 executedBaseAmount,
      int256 executedQuoteAmount,
      uint256 fee,
      uint256 im,
      uint256 loss,
      int24 currentTick
    ) = abi.decode(swapOutput[2], (int256, int256, uint256, uint256, uint256, int24));

    int256 annualizedNotional = executedBaseAmount * int256(5) / int256(365 * 2);
    // executedBaseAmount * liquidityIndex * timeTillMat / year * atomicFeeTakers
    int256 expectedFee = annualizedNotional * 5e16 / int256(WAD);

    assertEq(executedBaseAmount, -600e18);
    assertNotEq(executedQuoteAmount, 0);
    // todo: fix expected fee calculation in the test
//    assertAlmostEq(fee, uint256(-expectedFee), 100);
    assertEq(currentTick, currentTickVamm);
    // todo: another assertion that'd be helpful is to check that sum of settlement casfhlows is approx 0
  }

  function test_MINT_out_of_range_FT() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);
    token.mint(user1, 1001e18);
    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    redeemAccessPass(user1, 1, 2);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
      inputs[1] = abi.encode(address(token), 1001e18);
      inputs[2] = abi.encode(1, address(token), 1000e18);
      inputs[3] = abi.encode(
        1,  // accountId
        marketId,
        maturityTimestamp,
        -14580, // 4.3% 
        -14100, // 4.1%
        extendedPoolModule.getLiquidityForBase(-14580, -14100, 10000e18)    
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    vm.stopPrank();
    //uint256 lpUnfilledShortBeforeTrade = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;

    address user2 = vm.addr(2);
    vm.startPrank(user2);
    token.mint(user2, 10001e18);
    token.approve(address(peripheryProxy), 501e18);

    /// PERIPHERY FT SWAP COMMAND -> tick grows
    redeemAccessPass(user2, 1, 3);
    bytes[] memory swapOutput;
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(2, address(token), 500e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        -500e18,
        0 // todo: compute this properly
      );
      swapOutput = peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }
    int24 currentTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp); // 0% 69100
    assertEq(currentTickVamm, 69099); 

    (
      int256 executedBaseAmount,
      int256 executedQuoteAmount,
      uint256 fee,
      uint256 im,
      uint256 loss,
      int24 currentTick
    ) = abi.decode(swapOutput[3], (int256, int256, uint256, uint256, uint256, int24));

    assertEq(executedBaseAmount, 0);
    assertEq(executedQuoteAmount, 0);
    assertEq(fee, 0);
    assertEq(currentTick, currentTickVamm);


    uint256 eps = 10000; // 1e-14 * 1e18
    // LP
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, 0, "f l");
    // // TRADER
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, 0, "f t");

    vm.stopPrank();
  }

  function test_Recovery_From_Max_Tick() public {
    /*
    test_MINT_out_of_range_FT description:
      prev tick 5%
      LP 1000e18 base 4.1% 1.3%
      TRADE FT 500e18 base
      curent tick 0% (max tick)
     */
    test_MINT_out_of_range_FT(); 

    // execute Unwind -> flipping to VT
    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 601e18);

    token.approve(address(peripheryProxy), 601e18);

    /// PERIPHERY VT SWAP COMMAND
    bytes[] memory swapOutput;
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](3);
      inputs[0] = abi.encode(address(token), 601e18);
      inputs[1] = abi.encode(2, address(token), 600e18);
      inputs[2] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        600e18,
        0 // todo: compute this properly
      );
      swapOutput = peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    int24 currentTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp);
    assertLe(currentTickVamm, -13860);

    (
      int256 executedBaseAmount,
      int256 executedQuoteAmount,
      uint256 fee,
      uint256 im,
      uint256 loss,
      int24 currentTick
    ) = abi.decode(swapOutput[2], (int256, int256, uint256, uint256, uint256, int24));

    int256 annualizedNotional = executedBaseAmount * int256(5) / int256(365 * 2);
    // executedBaseAmount * liquidityIndex * timeTillMat / year * atomicFeeTakers
    int256 expectedFee = annualizedNotional * 5e16 / int256(WAD);

    assertEq(executedBaseAmount, 600e18);
    assertNotEq(executedQuoteAmount, 0);
    // todo: note, expectedFee calculation is not correct, need to fix the test
//    assertAlmostEq(fee, uint256(expectedFee), 100);
    assertEq(currentTick, currentTickVamm);
  }

  function test_MINT_VT_Settlement() public {
    setConfigs();

    vm.startPrank(user1);
    token.mint(user1, 1001e18);
    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    redeemAccessPass(user1, 1, 2);
    int128 lpLiquidity = extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18); // 833_203_486_935_127_427_677_715
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
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
    }

    vm.stopPrank();
    //uint256 lpUnfilledShortBeforeTrade = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;

    vm.startPrank(user2);
    token.mint(user2, 10001e18);
    token.approve(address(peripheryProxy), 501e18);

    /// PERIPHERY VT SWAP COMMAND -> tick grows
    bytes[] memory swapOutput;
    redeemAccessPass(user2, 1, 3);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(2, address(token), 500e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        500e18,
        0 // todo: compute this properly
      );
      swapOutput = peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    (
      int256 executedBaseAmount,
      int256 executedQuoteAmount,,,,
    ) = abi.decode(swapOutput[3], (int256, int256, uint256, uint256, uint256, int24));

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(101e16));
    vm.warp(maturityTimestamp + 1);
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);
    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));

    /// SETTLE TRADER
    {
      uint256 user2BalanceBeforeSettle = token.balanceOf(user2);
      // settlement CF = base * liqIndex + quote 
      int256 settlementCashflow = executedBaseAmount * maturityIndex / WAD.toInt() + executedQuoteAmount;
      // 1 below represents the maturity index at the time of the trade
      // todo: fee calc is likely not correct
//      int256 existingCollateral = 500e18 - executedBaseAmount * 1 * 25e17 / WAD.toInt() / 365 * 5e16 / WAD.toInt();
      int256 existingCollateral = 499760273972602739750;

      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)),
        bytes1(uint8(Commands.V2_CORE_WITHDRAW))
      );
      bytes[] memory inputs = new bytes[](2);
      inputs[0] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp
      );
      inputs[1] = abi.encode(2, address(token), settlementCashflow + existingCollateral);
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);

      uint256 collateralBalance = coreProxy.getAccountCollateralBalance(2, address(token));

      uint256 user2BalanceAfterSettle = token.balanceOf(user2);
      assertEq(collateralBalance, 0);
      assertEq(user2BalanceAfterSettle.toInt(), user2BalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
    }
    vm.stopPrank();

    /// SETTLE LP
    {
      vm.startPrank(user1);
      uint256 user1BalanceBeforeSettle = token.balanceOf(user1);
      // settlement CF = base * liqIndex + quote  (opposite of trader's)

      // note, adding +1 to settlement cashflow due to small discrepancy because of liquidity math
      int256 settlementCashflow = -executedBaseAmount * maturityIndex / WAD.toInt() - executedQuoteAmount + 1;
      // collateral = deposited margin + liqBooster - fees 
      // 1 below represents the maturity index at the time of the trade
      // todo: fee calc
//      int256 existingCollateral = 1001e18 - 10000e18 * 1 * 25e17 / WAD.toInt() / 365 * 1e16 / WAD.toInt();
      int256 existingCollateral = 999041095890410959001;

      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)),
        bytes1(uint8(Commands.V2_CORE_WITHDRAW))
      );
      bytes[] memory inputs = new bytes[](2);
      inputs[0] = abi.encode(
        1,  // accountId
        marketId,
        maturityTimestamp
      );
      inputs[1] = abi.encode(1, address(token), settlementCashflow + existingCollateral);
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);

      uint256 collateralBalance = coreProxy.getAccountCollateralBalance(1, address(token));

      uint256 user1BalanceAfterSettle = token.balanceOf(user1);
      assertEq(collateralBalance, 0);
      assertEq(user1BalanceAfterSettle.toInt(), user1BalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
    }
  }

  function test_MINT_FT_Settlement() public {
    setConfigs();

    vm.startPrank(user1);
    token.mint(user1, 1001e18);
    token.approve(address(peripheryProxy), 1001e18);

    // PERIPHERY LP COMMAND
    redeemAccessPass(user1, 1, 2);
    int128 lpLiquidity = extendedPoolModule.getLiquidityForBase(-14100, -13620, 10000e18); // 833_203_486_935_127_427_677_715
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(1);
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
    }

    vm.stopPrank();
    //uint256 lpUnfilledShortBeforeTrade = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;

    vm.startPrank(user2);
    token.mint(user2, 10001e18);
    token.approve(address(peripheryProxy), 501e18);

    /// PERIPHERY VT SWAP COMMAND -> tick grows
    bytes[] memory swapOutput;
    redeemAccessPass(user2, 1, 3);
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(2);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(2, address(token), 500e18);
      inputs[3] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        -500e18,
        0 // todo: compute this properly
      );
      swapOutput = peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    (
      int256 executedBaseAmount,
      int256 executedQuoteAmount,,,,
    ) = abi.decode(swapOutput[3], (int256, int256, uint256, uint256, uint256, int24));

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(101e16));
    vm.warp(maturityTimestamp + 1);
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);
    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));

    /// SETTLE TRADER
    {
      uint256 user2BalanceBeforeSettle = token.balanceOf(user2);
      // settlement CF = base * liqIndex + quote 
      int256 settlementCashflow = executedBaseAmount * maturityIndex / WAD.toInt() + executedQuoteAmount;

      // fee = annualizedNotional * atomic fee , note: executedBaseAmount is negative
      // 1 below represents the maturity index at the time of the trade
      // todo: double check the calculation of fees (for now using raw existing collateral from contracts)
//      int256 existingCollateral = 500e18 + executedBaseAmount * 1 * 25e17 / WAD.toInt() / 365 * 5e16 / WAD.toInt();
      int256 existingCollateral = 499760273972602739750;

    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)),
        bytes1(uint8(Commands.V2_CORE_WITHDRAW))
      );
      bytes[] memory inputs = new bytes[](2);
      inputs[0] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp
      );
        inputs[1] = abi.encode(2, address(token), settlementCashflow + existingCollateral);
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);

      uint256 collateralBalance = coreProxy.getAccountCollateralBalance(2, address(token));

      uint256 user2BalanceAfterSettle = token.balanceOf(user2);
      assertEq(collateralBalance, 0);
      assertEq(user2BalanceAfterSettle.toInt(), user2BalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
    }
     vm.stopPrank();

    /// SETTLE LP
    {
      vm.startPrank(user1);
      uint256 user1BalanceBeforeSettle = token.balanceOf(user1);
      // settlement CF = base * liqIndex + quote  (opposite of trader's)
      // todo: note, subtracting 1 from the settlement cashflow since there's a small discrepancy (need to check)
      int256 settlementCashflow = 
        -executedBaseAmount * 
        maturityIndex
        / WAD.toInt() 
        - executedQuoteAmount - 1;
      // 1 below represents the maturity index at the time of the trade
      // todo: uncomment below line once fee calc in the test is sorted
//      int256 existingCollateral = 1000e18 - 10000e18 * 1 * 25e17 / WAD.toInt() / 365 * 1e16 / WAD.toInt();
        int256 existingCollateral = 999041095890410959001;

      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)),
        bytes1(uint8(Commands.V2_CORE_WITHDRAW))
      );
      bytes[] memory inputs = new bytes[](2);
      inputs[0] = abi.encode(
        1,  // accountId
        marketId,
        maturityTimestamp
      );

      inputs[1] = abi.encode(1, address(token), settlementCashflow + existingCollateral);
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);

      uint256 collateralBalance = coreProxy.getAccountCollateralBalance(1, address(token));

      uint256 user1BalanceAfterSettle = token.balanceOf(user1);
      assertEq(collateralBalance, 0);
      assertEq(user1BalanceAfterSettle.toInt(), user1BalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
    }
  }

  function test_MINT_VT_UNWIND() public {
    // addr 1 mints between 4.1% 3.9% 10000e18 base
    // addr 2 FT 500e18 base 
    // liquidity index is now 1.01
    test_MINT_FT();
    int24 initialTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp);

    // int256 initLpFilled = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled;
    // uint256 initLpUnfilledShort = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;
    // uint256 initLpUnfilledLong = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong;

    // int256 initTraderExposure = datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled;

    // execute Unwind -> flipping to VT
    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 301e18);
    token.approve(address(peripheryProxy), 301e18);

    /// PERIPHERY VT SWAP COMMAND
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](3);
      inputs[0] = abi.encode(address(token), 301e18);
      inputs[1] = abi.encode(2, address(token), 300e18);
      inputs[2] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        300e18,
        0 // todo: compute this properly
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    int24 currentTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp);
    assertLe(currentTickVamm, initialTickVamm);

    uint256 liquidityIndex = 1_010_000_000_000_000_000;

    // traderExposure = base * liq index * daysTillMaturity / daysInYear
    uint256 traderExposure = div(ud60x18(200e18 * 2.5 * 1.01), ud60x18(365 * 1e18)).unwrap();

    uint256 eps = 1000; // 1e-15 * 1e18

    // LP
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, int256(traderExposure - eps));
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, int256(traderExposure + eps));
    // assertEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort
    //     + datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong,
    //   initLpUnfilledShort + initLpUnfilledLong
    // );

    // // TRADER
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, -int256(traderExposure - eps));
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, -int256(traderExposure + eps));
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, initTraderExposure);

    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledShort, 0);
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledLong, 0);

    vm.stopPrank();
  }

  function test_MINT_FT_UNWIND() public {
    // addr 1 mints between 4.1% 3.9% 10000e18 base
    // addr 2 VT 500e18 base 
    // liquidity index is now 1.01
    test_MINT_VT();
    int24 initialTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp);

    // int256 initLpFilled = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled;
    // uint256 initLpUnfilledShort = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort;
    // uint256 initLpUnfilledLong = datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong;

    // int256 initTraderExposure = datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled;

    // execute Unwind -> flipping to VT
    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 301e18);
    token.approve(address(peripheryProxy), 301e18);

    /// PERIPHERY FT SWAP COMMAND
    {
      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      bytes[] memory inputs = new bytes[](3);
      inputs[0] = abi.encode(address(token), 301e18);
      inputs[1] = abi.encode(2, address(token), 300e18);
      inputs[2] = abi.encode(
        2,  // accountId
        marketId,
        maturityTimestamp,
        -300e18,
        0 // todo: compute this properly
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    }

    int24 currentTickVamm = vammProxy.getVammTick(marketId, maturityTimestamp);
    assertLe(initialTickVamm, currentTickVamm);

    uint256 liquidityIndex = 1_010_000_000_000_000_000;

    // traderExposure = base * liq index * daysTillMaturity / daysInYear
    uint256 traderExposure = div(ud60x18(200e18 * 2.5 * 1.01), ud60x18(365 * 1e18)).unwrap();

    uint256 eps = 1000; // 1e-15 * 1e18

    // LP
    // assertAlmostEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, 
    //   -int256(traderExposure), 
    //   eps
    // );
    // assertEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledShort 
    //     + datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].unfilledLong,
    //   initLpUnfilledShort + initLpUnfilledLong
    // );

    // // TRADER
    // assertAlmostEq(
    //   datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, 
    //   traderExposure, 
    //   eps
    // );
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, initTraderExposure);

    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledShort, 0);
    // assertEq(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].unfilledLong, 0);

    vm.stopPrank();
  }
}
pragma solidity >=0.8.19;

import "./utils/BaseScenario.sol";
import "./utils/TestUtils.sol";

import {CollateralConfiguration} from "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import {ProtocolRiskConfiguration} from "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import {Account} from "@voltz-protocol/core/src/storage/Account.sol";
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
import { sd59x18, abs } from "@prb/math/SD59x18.sol";

 import "forge-std/console2.sol";

contract MultiMarketsScenarios is TestUtils, BaseScenario {
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
  uint32 maturityTimestamp2;
  ExtendedPoolModule extendedPoolModule; // used to convert base to liquidity :)

  using SetUtil for SetUtil.Bytes32Set;

  struct TakerExecutedAmounts {
    uint256 depositedAmount;
    int256 executedBaseAmount;
    int256 executedQuoteAmount;
    uint256 fee;
    uint256 im;
  }

  struct MakerExecutedAmounts {
    int256 baseAmount;
    uint256 depositedAmount;
    int24 tickLower;
    int24 tickUpper;
    uint256 fee;
    uint256 im;
  }

  function setUp() public {
    super._setUp();
    user1 = vm.addr(1);
    user2 = vm.addr(2);
    marketId = 1;
    // in 30 days pools (time will be advanced by 1 day before creating the pools)
    maturityTimestamp = uint32(block.timestamp) + 86400 + 86400 * 30; 
    maturityTimestamp2 = uint32(block.timestamp) + 86400 + 86400 * 365; // one year pool
    extendedPoolModule = new ExtendedPoolModule();
  }

  function setPool(uint32 _maturityTimestamp) public {
    vm.startPrank(owner);

    VammConfiguration.Immutable memory immutableConfig = VammConfiguration.Immutable({
        maturityTimestamp: _maturityTimestamp,
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
    vm.warp(block.timestamp + 86400); // advance by 1 days
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
    vammProxy.increaseObservationCardinalityNext(marketId, _maturityTimestamp, 16);
    vammProxy.setMakerPositionsPerAccountLimit(1);


    vm.stopPrank();
  }

  function setConfigs() public {

    // COLLATERAL & PROTOCOL RISK & MARKET
    {
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
            address(aaveV3RateOracle),
            3600
        );
        datedIrsProxy.configureProduct(
        ProductConfiguration.Data({
                productId: productId,
                coreProxy: address(coreProxy),
                poolAddress: address(vammProxy),
                takerPositionsPerAccountLimit: 3
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

        vm.stopPrank();
    }
    
    setPool(maturityTimestamp);
    setPool(maturityTimestamp2);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(1e18));

    // ACCESS PASS
    addressPassNftInfo.add(keccak256(abi.encodePacked(user1, uint256(1))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(user2, uint256(1))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(vm.addr(3), uint256(1))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(vm.addr(4), uint256(1))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(vm.addr(5), uint256(1))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(vm.addr(6), uint256(1))));

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

  function newMaker(
    uint128 _marketId,
    uint32 _maturityTimestamp,
    uint128 accountId,
    address user,
    uint256 count,
    uint256 merkleIndex,
    uint256 toDeposit,
    int256 baseAmount,
    int24 tickLower,
    int24 tickUpper
    ) public returns (MakerExecutedAmounts memory){
    vm.startPrank(user);

    token.mint(user, toDeposit);

    token.approve(address(peripheryProxy), toDeposit);

    redeemAccessPass(user, count, merkleIndex);

    // PERIPHERY LP COMMAND
    int128 liquidity = extendedPoolModule.getLiquidityForBase(tickLower, tickUpper, baseAmount);
    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
    );
    bytes[] memory inputs = new bytes[](4);
    inputs[0] = abi.encode(accountId);
    inputs[1] = abi.encode(address(token), toDeposit);
    inputs[2] = abi.encode(accountId, address(token), toDeposit - 1e18);
    inputs[3] = abi.encode(
        accountId,
        _marketId,
        _maturityTimestamp,
        tickLower,
        tickUpper,
        liquidity
    );
    bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    (
      uint256 fee,
      uint256 im
    ) = abi.decode(output[3], (uint256, uint256));

    vm.stopPrank();

    return MakerExecutedAmounts({
      baseAmount: baseAmount,
      depositedAmount: toDeposit,
      tickLower: tickLower,
      tickUpper: tickUpper,
      fee: fee,
      im: im
    });

  }

  function newTaker(
    uint128 _marketId,
    uint32 _maturityTimestamp,
    uint128 accountId,
    address user,
    uint256 count,
    uint256 merkleIndex,
    uint256 toDeposit,
    int256 baseAmount
    ) public returns (TakerExecutedAmounts memory executedAmounts) {
    uint256 margin = toDeposit - 1e18; // minus liquidation booster

    vm.startPrank(user);

    token.mint(user, toDeposit);

    token.approve(address(peripheryProxy), toDeposit);

    redeemAccessPass(user, count, merkleIndex);

    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
    );
    bytes[] memory inputs = new bytes[](4);
    inputs[0] = abi.encode(accountId);
    inputs[1] = abi.encode(address(token), toDeposit);
    inputs[2] = abi.encode(accountId, address(token), margin);
    inputs[3] = abi.encode(
        accountId,  // accountId
        _marketId,
        _maturityTimestamp,
        baseAmount,
        0 // MIN_SQRT_LIMIT, VT
    );
    bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    // todo: add unrealized loss to exposures
    (
      executedAmounts.executedBaseAmount,
      executedAmounts.executedQuoteAmount,
      executedAmounts.fee, 
      executedAmounts.im,,
    ) = abi.decode(output[3], (int256, int256, uint256, uint256, uint256, int24));

    executedAmounts.depositedAmount = toDeposit;

    vm.stopPrank();

  }

  function checkImMaker(
    uint128 _marketId,
    uint32 _maturityTimestamp,
    uint128 accountId,
    address user,
    MakerExecutedAmounts memory executedAmounts
  ) public {

      (
      bool liquidatable,
      uint256 initialMarginRequirement,
      uint256 liquidationMarginRequirement,
      uint256 highestUnrealizedLoss
      ) = coreProxy.isLiquidatable(accountId, address(token));

      console2.log("liquidatable", liquidatable);
      console2.log("initialMarginRequirement", initialMarginRequirement); // 785.8207615
      console2.log("liquidationMarginRequirement", liquidationMarginRequirement); // 392.9103807
      console2.log("highestUnrealizedLoss", highestUnrealizedLoss);

      // get unfilled base and quote balances of maker
      (uint256 unfilledBaseLong, uint256 unfilledQuoteLong, uint256 unfilledBaseShort, uint256 unfilledQuoteShort) =
      vammProxy.getAccountUnfilledBaseAndQuote(_marketId, _maturityTimestamp, accountId);

      console2.log("unfilledBaseLong", unfilledBaseLong);
      console2.log("unfilledQuoteLong", unfilledQuoteLong);
      console2.log("unfilledBaseShort", unfilledBaseShort);
      console2.log("unfilledQuoteShort", unfilledQuoteShort);

      // todo: investigate why this fails, in theory these should be equal
//      assertEq(uint256(executedAmounts.baseAmount), unfilledBaseLong+unfilledBaseShort);
      assertEq(liquidatable, false);
      assertGe(initialMarginRequirement, liquidationMarginRequirement);

    // check against IM
    // margin > im + unrealizedLoss
    // compute unrealized loss

    // check it fails if position exposure is increased
      // through unrealized
      // through withdraw
  }

  // function editTaker(
  //   uint128 _marketId,
  //   uint32 _maturityTimestamp,
  //   uint128 accountId,
  //   address user,
  //   uint256 toDeposit,
  //   int256 baseAmount
  //   ) public returns (ExecutedAmounts memory executedAmounts) {
  //   uint256 margin = toDeposit;

  //   vm.startPrank(user);

  //   token.mint(user, toDeposit);

  //   token.approve(address(peripheryProxy), toDeposit);

  //   bytes memory commands = abi.encodePacked(
  //       bytes1(uint8(Commands.TRANSFER_FROM)),
  //       bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
  //       bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
  //   );
  //   bytes[] memory inputs = new bytes[](3);
  //   inputs[0] = abi.encode(address(token), toDeposit);
  //   inputs[1] = abi.encode(accountId, address(token), margin);
  //   inputs[2] = abi.encode(
  //       accountId,  // accountId
  //       _marketId,
  //       _maturityTimestamp,
  //       baseAmount,
  //       0
  //   );
  //   bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);


  //   (
  //     executedAmounts.executedBaseAmount,
  //     executedAmounts.executedQuoteAmount,
  //     executedAmounts.fee,,
  //   ) = abi.decode(output[2], (int256, int256, uint256, uint256, int24));

  //   vm.stopPrank();
  // }

  // function editMaker(
  //   uint128 _marketId,
  //   uint32 _maturityTimestamp,
  //   uint128 accountId,
  //   address user,
  //   uint256 toDeposit,
  //   int256 baseAmount,
  //   int24 tickLower,
  //   int24 tickUpper
  //   ) public returns (uint256 fee) {
  //   vm.startPrank(user);

  //   uint256 margin = toDeposit; // minus liquidation booster

  //   token.mint(user, toDeposit);

  //   token.approve(address(peripheryProxy), toDeposit);

  //   // PERIPHERY LP COMMAND
  //   int128 liquidity = extendedPoolModule.getLiquidityForBase(tickLower, tickUpper, baseAmount);
  //   bytes memory commands = abi.encodePacked(
  //       bytes1(uint8(Commands.TRANSFER_FROM)),
  //       bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
  //       bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
  //   );
  //   bytes[] memory inputs = new bytes[](3);
  //   inputs[0] = abi.encode(address(token), toDeposit);
  //   inputs[1] = abi.encode(accountId, address(token), margin);
  //   inputs[2] = abi.encode(
  //       accountId,
  //       _marketId,
  //       _maturityTimestamp,
  //       tickLower,
  //       tickUpper,
  //       liquidity
  //   );
  //   bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);

  //   (
  //     fee,
  //   ) = abi.decode(output[2], (uint256, uint256));

  //   vm.stopPrank();
  // }

  function redeemAccessPass(address user, uint256 count, uint256 merkleIndex) public {
    accessPassNft.redeem(
      user,
      count,
      merkle.getProof(addressPassNftInfo.values(), merkleIndex),
      merkle.getRoot(addressPassNftInfo.values())
    );
  }

  ///////// TESTS /////////

  function test_track_margin_low_volatility() public {
    /// note same positions taken by different users at 0.5 days interval
    /// change in the liquidity index
    setConfigs();

    TakerExecutedAmounts[] memory takerAmounts = new TakerExecutedAmounts[](3);
    MakerExecutedAmounts[] memory makerAmounts = new MakerExecutedAmounts[](3);

    // apy 33.9%
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP - 1st pool
    makerAmounts[0] = newMaker(
        marketId,
        maturityTimestamp,
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9%
    );

    // check im
    checkImMaker(
      marketId,
        maturityTimestamp,
        1, // accountId
        vm.addr(1), // user
        makerAmounts[0]
    );

    vm.warp(block.timestamp + 86400); // advance by 1 day

    // VT - 1st pool
    takerAmounts[0] = newTaker(
        marketId,
        maturityTimestamp,
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    
  }

  // function test_liquidation_two_markets() public {
  //   /// note same positions taken by different users at 0.5 days interval
  //   /// no change in the liquidity index
  //   setConfigs();

  //   ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

  //   // console2.log("-------- LP -------");
  //   newMaker(
  //       marketId,
  //       maturityTimestamp,
  //       1, // accountId
  //       vm.addr(1), // user
  //       1, // count,
  //       2, // merkleIndex
  //       1001e18, // toDeposit
  //       10000e18, // baseAmount
  //       -14100, // 4.1%
  //       -13620 // 3.9% 
  //   );
  //   editMaker(
  //       marketId,
  //       maturityTimestamp2,
  //       1, // accountId
  //       vm.addr(1), // user
  //       1001e18, // toDeposit
  //       10000e18, // baseAmount
  //       -14100, // 4.1%
  //       -13620 // 3.9% 
  //   );

  //   // FT
  //   // console2.log("-------- FT -------");
  //   amounts[0] = newTaker(
  //       marketId,
  //       maturityTimestamp,
  //       2, // accountId
  //       vm.addr(2), // user
  //       1, // count,
  //       3, // merkleIndex
  //       8e18, // toDeposit - margin = 7e18
  //       -500e18 // baseAmount
  //   ); // MR = 500e18 * 2.5/265 * 2 = 6.849315068493150000
  //   // console2.log("IM", amounts[0].im);
  //   // console2.log("BASE", amounts[0].executedBaseAmount);

  //   // console2.log("-------- FT -------");
  //   amounts[1] = editTaker(
  //       marketId,
  //       maturityTimestamp2,
  //       2, // accountId
  //       vm.addr(2), // user
  //       0, // toDeposit - margin = 7e18
  //       -1e18 // baseAmount
  //   ); // MR = 500e18 * 2.5/265 * 2 = 6.849315068493150000

  //   vm.warp(block.timestamp + 43200); // advance by 0.5 days
  //   aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(1.01e18)); // 2 days left
  //   // LMR = 500e18 * 2/365 * li2 = 7.5471
  //   // unrealized pnl = base * li2 * (twap * 2/365 + 1) - 500.136  = 500 * li * 1.000219 - 500.136 =

  //   //console2.log("-------- LIQUIDATION -------");
  //   // LIQUIDQATE
  //   vm.startPrank(vm.addr(3));
  //   redeemAccessPass(vm.addr(3), 1, 4);
  //   coreProxy.createAccount(3, vm.addr(3));
  //   coreProxy.liquidate(2, 3, address(token));
  //   vm.stopPrank();
  // }

  function test_settlement_cashflow_after_maturity() public {
  }

  function test_settlement_after_liquidation() public {
  }

  function test_settlement_on_long_pool() public {
  }

  function test_margin_requirements() public {
  }
}
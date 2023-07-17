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

// import "forge-std/console2.sol";

contract ComplexScenarios is BaseScenario, TestUtils {
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

  struct ExecutedAmounts {
    int256 executedBaseAmount;
    int256 executedQuoteAmount;
    uint256 fee;
  }

  function setUp() public {
    super._setUp();
    user1 = vm.addr(1);
    user2 = vm.addr(2);
    marketId = 1;
    maturityTimestamp = uint32(block.timestamp) + 345600; // in 4 days
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
    vammProxy.increaseObservationCardinalityNext(marketId, maturityTimestamp, 16);
    vammProxy.setMakerPositionsPerAccountLimit(1);

    vm.stopPrank();

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

  function redeemAccessPass(address user, uint256 count, uint256 merkleIndex) public {
    accessPassNft.redeem(
      user,
      count,
      merkle.getProof(addressPassNftInfo.values(), merkleIndex),
      merkle.getRoot(addressPassNftInfo.values())
    );
  }

  function newTaker(
    uint128 accountId,
    address user,
    uint256 count,
    uint256 merkleIndex,
    uint256 toDeposit,
    int256 baseAmount
    ) public returns (ExecutedAmounts memory executedAmounts) {
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
        marketId,
        maturityTimestamp,
        baseAmount,
        0
    );
    bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    (
      executedAmounts.executedBaseAmount,
      executedAmounts.executedQuoteAmount,
      executedAmounts.fee,,,
    ) = abi.decode(output[3], (int256, int256, uint256, uint256, uint256, int24));

    vm.stopPrank();
  }

  function editTaker(
    uint128 accountId,
    address user,
    uint256 toDeposit,
    int256 baseAmount
    ) public returns (ExecutedAmounts memory executedAmounts) {
    uint256 margin = toDeposit;

    vm.startPrank(user);

    token.mint(user, toDeposit);

    token.approve(address(peripheryProxy), toDeposit);

    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
    );
    bytes[] memory inputs = new bytes[](3);
    inputs[0] = abi.encode(address(token), toDeposit);
    inputs[1] = abi.encode(accountId, address(token), margin);
    inputs[2] = abi.encode(
        accountId,  // accountId
        marketId,
        maturityTimestamp,
        baseAmount,
        0
    );
    bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);


    (
      executedAmounts.executedBaseAmount,
      executedAmounts.executedQuoteAmount,
      executedAmounts.fee,,
    ) = abi.decode(output[2], (int256, int256, uint256, uint256, int24));

    vm.stopPrank();
  }

  function newMaker(
    uint128 accountId,
    address user,
    uint256 count,
    uint256 merkleIndex,
    uint256 toDeposit,
    int256 baseAmount,
    int24 tickLower,
    int24 tickUpper
    ) public returns (uint256 fee){
    vm.startPrank(user);

    uint256 margin = toDeposit - 1e18; // minus liquidation booster

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
    inputs[2] = abi.encode(accountId, address(token), margin);
    inputs[3] = abi.encode(
        accountId,
        marketId,
        maturityTimestamp,
        tickLower,
        tickUpper,
        liquidity
    );
    bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    (
      fee,
    ) = abi.decode(output[3], (uint256, uint256));

    vm.stopPrank();
  }

  function editMaker(
    uint128 accountId,
    address user,
    uint256 toDeposit,
    int256 baseAmount,
    int24 tickLower,
    int24 tickUpper
    ) public returns (uint256 fee) {
    vm.startPrank(user);

    uint256 margin = toDeposit; // minus liquidation booster

    token.mint(user, toDeposit);

    token.approve(address(peripheryProxy), toDeposit);

    // PERIPHERY LP COMMAND
    int128 liquidity = extendedPoolModule.getLiquidityForBase(tickLower, tickUpper, baseAmount);
    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
    );
    bytes[] memory inputs = new bytes[](3);
    inputs[0] = abi.encode(address(token), toDeposit);
    inputs[1] = abi.encode(accountId, address(token), margin);
    inputs[2] = abi.encode(
        accountId,
        marketId,
        maturityTimestamp,
        tickLower,
        tickUpper,
        liquidity
    );
    bytes[] memory output = peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    (
      fee,
    ) = abi.decode(output[2], (uint256, uint256));

    vm.stopPrank();
  }

  function settle(
    uint128 accountId,
    address user,
    int256 settlementCashflow,
    int256 existingCollateral
  ) public {
    vm.startPrank(user);
    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)),
        bytes1(uint8(Commands.V2_CORE_WITHDRAW))
    );
    bytes[] memory inputs = new bytes[](2);
    inputs[0] = abi.encode(
        accountId,
        marketId,
        maturityTimestamp
    );
    inputs[1] = abi.encode(accountId, address(token), settlementCashflow + existingCollateral);
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    vm.stopPrank();
  }

  function settleWithUnknownCashflow(
    uint128 accountId,
    address user,
    uint256 liquidationBooster,
    int256 existingBalance // included liq booster & initial deposit (no fee)
  ) public returns (int256) {
    vm.startPrank(user);
    bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE))
    );
    bytes[] memory inputs = new bytes[](1);
    inputs[0] = abi.encode(
        accountId,
        marketId,
        maturityTimestamp
    );
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    uint256 collateralBalance = coreProxy.getAccountCollateralBalance(accountId, address(token));

    bytes memory commands2 = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_WITHDRAW))
    );
    bytes[] memory inputs2 = new bytes[](1);
    inputs2[0] = abi.encode(accountId, address(token), collateralBalance + liquidationBooster);
    peripheryProxy.execute(commands2, inputs2, block.timestamp + 1);
    vm.stopPrank();

    return int256(collateralBalance + liquidationBooster) - existingBalance;
  }

  function checkSettle(
    uint128 accountId,
    address user,
    int256 initialDeposit,
    int256 executedBaseAmount,
    int256 executedQuoteAmount,
    uint256 fee,
    int256 maturityIndex // int to fit the calculations
  ) public  returns (int256 settlementCashflow){
    uint256 userBalanceBeforeSettle = token.balanceOf(user);
    // settlement CF = base * liqIndex + quote 
    settlementCashflow = executedBaseAmount * maturityIndex / WAD.toInt() + executedQuoteAmount;
    // fee = annualizedNotional * atomic fee
    int256 existingCollateral = initialDeposit - fee.toInt() - 1; // -1 becausefee is rounded down

    settle(
        accountId, // accountId
        user, // user
        settlementCashflow,
        existingCollateral
    );

    uint256 collateralBalance = coreProxy.getAccountCollateralBalance(accountId, address(token));

    uint256 userBalanceAfterSettle = token.balanceOf(user);
    // console2.log(accountId);
    assertEq(collateralBalance, 0);
    assertEq(userBalanceAfterSettle.toInt(), userBalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
  }

  function checkWithUnknownCashflow(
    uint128 accountId,
    address user,
    uint256 liquidationBooster,
    int256 initialDeposit,
    uint256 fee
  ) public  returns (int256 settlementCashflow){
    uint256 userBalanceBeforeSettle = token.balanceOf(user);

    int256 existingCollateral = initialDeposit - fee.toInt() - 1; // -1 because fee is rounded down

    settlementCashflow = settleWithUnknownCashflow(
        accountId,
        user,
        liquidationBooster,
        existingCollateral
    );

    uint256 collateralBalance = coreProxy.getAccountCollateralBalance(accountId, address(token));

    uint256 userBalanceAfterSettle = token.balanceOf(user);
    assertEq(collateralBalance, 0);
    assertEq(userBalanceAfterSettle.toInt(), userBalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
  }

  /// @dev gets average fixed rate in wad
  function getAvgRate(
    int256 base,
    int256 quote,
    int256 liquidityIndex,
    int256 yearsUntilMaturityWad
  ) public returns (int256) {
    // quote = -base * li * (1 + avgprice * yearsTillMat)
    // todo: consider returning a uint256 given the fact that the rate cannon be negative
    SD59x18 one = sd59x18(WAD.toInt());
    return
        SD59x18.unwrap(
            abs(sd59x18(quote).div(sd59x18(-base).mul(sd59x18(liquidityIndex))))
            .sub(one)
            .div(sd59x18(yearsUntilMaturityWad))
        );
  }

  function test_entry_at_different_time() public {
    /// note same positions taken by different users at 0.5 days interval
    /// no change in the liquidity index
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

   amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days

    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days

    uint256 fee5 = newMaker(
        5, // accountId
        vm.addr(5), // user
        1, // count,
        6, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    amounts[2] = newTaker(
        6, // accountId
        vm.addr(6), // user
        1, // count,
        7, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(maturityTimestamp + 1);

    checkSettle(
        1, // accountId,
        vm.addr(1), // user
        1001e18, // deposited margin
        -(amounts[0].executedBaseAmount + amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[0].executedQuoteAmount + amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee1,
        1e18
    );

    checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount,
        amounts[0].executedQuoteAmount,
        amounts[0].fee,
        1e18
    );

    checkSettle(
        3, // accountId,
        vm.addr(3), // user
        1001e18, // deposited margin
        -(amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee3,
        1e18
    );

    checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        1e18
    );

    checkSettle(
        5, // accountId,
        vm.addr(5), // user
        1001e18, // deposited margin
        -(amounts[2].executedBaseAmount / 3),
        -(amounts[2].executedQuoteAmount / 3),
        fee5,
        1e18
    );

    checkSettle(
        6, // accountId,
        vm.addr(6), // user
        101e18, // deposited margin
        amounts[2].executedBaseAmount,
        amounts[2].executedQuoteAmount,
        amounts[2].fee,
        1e18
    );

  }

  function test_changing_index() public {
    /// note same positions taken by different users at 0.5 days interval
    /// change in the liquidity index, almost constant apy 33.9% 
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP
    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004)); // 2 days till end

    // LP
    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); // -13897
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004 * 1.0004)); // 1.5 days

    // LP
    uint256 fee5 = newMaker(
        5, // accountId
        vm.addr(5), // user
        1, // count,
        6, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // TRADER
    amounts[2] = newTaker(
        6, // accountId
        vm.addr(6), // user
        1, // count,
        7, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(maturityTimestamp + 1);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(
        10004e14 * 1.002
    )); // 1.002 = 1.0004^5
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));
    assertLe(maturityIndex, 10025e14);
    assertGe(maturityIndex, 10024e14);

    int256[] memory cashflows = new int256[](6);

    cashflows[0] = checkSettle(
        1, // accountId,
        vm.addr(1), // user
        1001e18, // deposited margin
        -(amounts[0].executedBaseAmount + amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[0].executedQuoteAmount + amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee1,
        maturityIndex
    );
    
    cashflows[1] = checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount,
        amounts[0].executedQuoteAmount,
        amounts[0].fee,
        maturityIndex
    );

    cashflows[2] = checkSettle(
        3, // accountId,
        vm.addr(3), // user
        1001e18, // deposited margin
        -(amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee3,
        maturityIndex
    );

    cashflows[3] = checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        maturityIndex
    );

    cashflows[4] = checkSettle(
        5, // accountId,
        vm.addr(5), // user
        1001e18, // deposited margin
        -(amounts[2].executedBaseAmount / 3),
        -(amounts[2].executedQuoteAmount / 3),
        fee5,
        maturityIndex
    );

    cashflows[5] = checkSettle(
        6, // accountId,
        vm.addr(6), // user
        101e18, // deposited margin
        amounts[2].executedBaseAmount,
        amounts[2].executedQuoteAmount,
        amounts[2].fee,
        maturityIndex
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp); // 4.0165% -13905
    // console2.log("tick", currentTick); // -13905
    // apy = 33.9% => VTs have to profit at the end

    // LPs
    assertLt(cashflows[0], 0, "0");
    assertLt(cashflows[2], 0, "2");
    assertLt(cashflows[4], 0, "4");

    // cashflow ~= + 500 * ((1.0004^(365/0.5))^(2.5/365) - 1) - 500 * (1.04^(2.5/365) - 1)
    assertGt(cashflows[1], 0, "1");
    assertAlmostEq(cashflows[1], int256(866463000000000000), 5e16); //5% error

    // cashflow ~= + 500 * ((1.0004^(365/0.5))^(2/365) - 1) - 500 * (1.04^(2/365) - 1)
    assertGt(cashflows[3], 0, "3");
    assertAlmostEq(cashflows[3], int(693015000000000000), 5e16);

    // cashflow ~= + 500 * ((1.0004^(365/0.5))^(1.5/365) - 1) - 500 * (1.04^(1.5/365) - 1)
    assertGt(cashflows[5], 0, "5");
    assertAlmostEq(cashflows[5], int(519642000000000000), 5e16);

    assertAlmostEq(-(cashflows[0] + cashflows[2] + cashflows[4]), cashflows[1] + cashflows[3] + cashflows[5], 1000);
  }

  // todo, needs new setup
  function test_3months_pool() public {
  }

  function test_high_variable_rate_volatility() public {
    /// note same positions taken by different users at 0.5 days interval
    /// change in the liquidity index
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

    // apy 33.9%
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP
    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // rate 7.57% 
    // index1 * 1.0001 
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(100050004e10)); // 2 days till end

    // LP
    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 
    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // apy to 107.43%
    // index = 1.0001 * 1.0004 * 1.001
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(100150054004e7)); // 1.5 days

    // LP
    uint256 fee5 = newMaker(
        5, // accountId
        vm.addr(5), // user
        1, // count,
        6, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // TRADER
    amounts[2] = newTaker(
        6, // accountId
        vm.addr(6), // user
        1, // count,
        7, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(maturityTimestamp + 1);
    // apy to 0.244%
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(
        1001510555045400400
    )); // index =  1.0001 * 1.0004 * 1.001 * 1.00001
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));

    int256[] memory cashflows = new int256[](6);

    cashflows[0] = checkSettle(
        1, // accountId,
        vm.addr(1), // user
        1001e18, // deposited margin
        -(amounts[0].executedBaseAmount + amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[0].executedQuoteAmount + amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee1,
        maturityIndex
    );
    
    cashflows[1] = checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount,
        amounts[0].executedQuoteAmount,
        amounts[0].fee,
        maturityIndex
    );

    cashflows[2] = checkSettle(
        3, // accountId,
        vm.addr(3), // user
        1001e18, // deposited margin
        -(amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee3,
        maturityIndex
    );

    cashflows[3] = checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        maturityIndex
    );

    cashflows[4] = checkSettle(
        5, // accountId,
        vm.addr(5), // user
        1001e18, // deposited margin
        -(amounts[2].executedBaseAmount / 3),
        -(amounts[2].executedQuoteAmount / 3),
        fee5,
        maturityIndex
    );

    cashflows[5] = checkSettle(
        6, // accountId,
        vm.addr(6), // user
        101e18, // deposited margin
        amounts[2].executedBaseAmount,
        amounts[2].executedQuoteAmount,
        amounts[2].fee,
        maturityIndex
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp); // 4.0165% -13905
    // console2.log("tick", currentTick); // -13905
    // average apy = 24.94%
    // 33.9 1st 0.5 day, 7.3 for 0.5 day, 107.43 for 0.5 , 0.244 for the last 1.5 days

    // LPs
    assertLt(cashflows[0], 0, "0");
    assertLt(cashflows[2], 0, "2");
    assertGt(cashflows[4], 0, "4"); // took VT while apy was at 0.244%

    /* cashflow ~=
        + 500 * (1.0757^(0.5/365) - 1)
        + 500 * (2.0743^(0.5/365) - 1)
        + 500 * (1.00244^(1.5/365) - 1)
        - 500 * ((1.04+0.003)^(2.5/365) - 1) = 0.410779889713060625161
    */


    assertGt(cashflows[1], 0, "1");
    assertAlmostEq(cashflows[1], int256(4.107798897E17), 5e15);

    /* cashflow ~=
        + 500 * (2.0743^(0.5/365) - 1) 
        + 500 * (1.00244^(1.5/365) - 1) 
        - 500 * ((1.04+0.003)^(2/365) - 1) = 0.38964074185606124161
    */
    assertGt(cashflows[3], 0, "3");
    assertAlmostEq(cashflows[3], int(3.896407419E17), 5e15);

    // cashflow ~= + 500 * (1.00244^(1.5/365) - 1)  - 500 * (1.04^(1.5/365) - 1)
    assertLt(cashflows[5], 0, "5"); 
    assertAlmostEq(cashflows[5], -int(75915400000000000), 1e16);

    assertAlmostEq(-(cashflows[0] + cashflows[2] + cashflows[4]), cashflows[1] + cashflows[3] + cashflows[5], 1000);
  }

  function test_high_fixed_rate_volatility() public {
    /// note same positions taken by different users at 0.5 days interval
    /// big changes in the variable, almost constant apy 33.9% 
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);
    int256[] memory avgRates = new int256[](3);

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP
    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -20820, // 8%
        69060// 0.00102% 
    );

    // VT
    amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        45e18 // baseAmount
    );
    avgRates[0] = getAvgRate(
        amounts[0].executedBaseAmount, 
        amounts[0].executedQuoteAmount,
        10004e14,
        int256(25e17) / 365
    );

    // console2.log("avg rate", avgRates[0]);

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("Tick", currentTick); // -20461 = 7.7368%
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004)); // 2 days till end

    // LP
    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10e18, // baseAmount
        -14580, // 4.3%
        -14100 // 4.1% 
    );

    // FT
    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        -2000e18 // baseAmount
    );
    avgRates[1] = getAvgRate(
        amounts[1].executedBaseAmount, 
        amounts[1].executedQuoteAmount,
        10004e14 * 1.0004,
        int256(20e17) / 365
    );
    // console2.log("avg rate", avgRates[1]);

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); // 37669 = 0.02312%
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004 * 1.0004)); // 1.5 days

    // LP
    uint256 fee5 = newMaker(
        5, // accountId
        vm.addr(5), // user
        1, // count,
        6, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -13620, // 3.9% 
        -13380 // 3.8%
    );

    // VT
    amounts[2] = newTaker(
        6, // accountId
        vm.addr(6), // user
        1, // count,
        7, // merkleIndex
        101e18, // toDeposit
        2010e18 // baseAmount
    );
    avgRates[2] = getAvgRate(
        amounts[2].executedBaseAmount, 
        amounts[2].executedQuoteAmount,
        10004e14 * 1.0004 * 1.0004,
        int256(15e17) / 365
    );
    // console2.log("avg rate", avgRates[2]);

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp); // 4.0165% -13905
    // console2.log("tick", currentTick); // -13382 = 3.8119%

    vm.warp(maturityTimestamp + 1);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(
        10004e14 * 1.002
    )); // 1.002 = 1.0004^5
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));
    assertLe(maturityIndex, 10025e14);
    assertGe(maturityIndex, 10024e14);

    int256[] memory cashflows = new int256[](6);

    cashflows[0] = checkWithUnknownCashflow(
        1, // accountId,
        vm.addr(1), // user
        1e18,
        1001e18,
        fee1
    );
    
    cashflows[1] = checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount,
        amounts[0].executedQuoteAmount,
        amounts[0].fee,
        maturityIndex
    );

    cashflows[2] = checkWithUnknownCashflow(
        3, // accountId,
        vm.addr(3), // user
        1e18,
        1001e18,
        fee3
    );

    cashflows[3] = checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        maturityIndex
    );

    cashflows[4] = checkWithUnknownCashflow(
        5, // accountId,
        vm.addr(5), // user
        1e18,
        1001e18,
        fee5
    );

    cashflows[5] = checkSettle(
        6, // accountId,
        vm.addr(6), // user
        101e18, // deposited margin
        amounts[2].executedBaseAmount,
        amounts[2].executedQuoteAmount,
        amounts[2].fee,
        maturityIndex
    );

    // LPs
    // 4% initial fixed rate
    // 1st LP: 8% - 0.00102% for 10_000 base
        // liquidity used 1st trader with 45 base, FT
        // then used by 2nd trader with 2000 in VT, 
        // then almost fully recovered by 3rd one but still in VT
    // 2nd LP: 4.3 - 4.1 for 10 base
        // used by 2nd trader -> VT position
    // 3rd LP:  3.9 - 3.8 for 10_000 base
        // used by 3rd trader -> FT position
    // RATE CHANGE:
        // avg rate 5.5578%, 7.7368% current rate
        // avg rate 0.04405%, current rate 0.02312%
        // avg rate 0.55812 %, current rate 3.8119%
    assertGt(cashflows[0], 0, "0");
    assertGt(cashflows[2], 0, "2");
    assertLt(cashflows[4], 0, "4");

    // VT
    /* cashflow ~=
        + 45 * (1.33902^(2.5/365) - 1) // variable
        - 45 * (1.077368^(0.5/365) - 1) 
        - 45 * (1.002312^(0.5/365) - 1) 
        - 45 * (1.038119^(1.5/365) - 1)
    */
    assertGt(cashflows[1], 0, "1");
    assertAlmostEq(cashflows[1], int256(78415700000000000), 1e16);

    // FT
    /* cashflow ~=
        - 2000 * (1.33902^(2/365) - 1) 
        + 2000 * (1.0004405^(2/365) - 1) 
    */
    assertLt(cashflows[3], 0, "3");
    assertAlmostEq(cashflows[3], int(-3197050000000000000), 5e16);

    // VT -3.152 964 174 194 207 618
    /* cashflow ~=
        + 2010 * (1.33902^(1.5/365) - 1) 
        - 2010 * (1.0055812^(1.5/365) - 1) 
    */
    assertGt(cashflows[5], 0, "5");
    assertAlmostEq(cashflows[5], int(2366960000000000000), 5e16);

    assertAlmostEq(-(cashflows[0] + cashflows[2] + cashflows[4]), cashflows[1] + cashflows[3] + cashflows[5], 1000);
  }

  function test_positions_editing() public {
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP
    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004)); // 2 days till end

    // LP
    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004 * 1.0004)); // 1.5 days

    // LP BURN
    uint256 fee5 = editMaker(
        1, // accountId
        vm.addr(1), // user
        0, // toDeposit
        -5000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // UNWIND
    amounts[2] = editTaker(
        2, // accountId
        vm.addr(2), // user
        0, // toDeposit
        -200e18 // baseAmount
    );

    vm.warp(maturityTimestamp + 1);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(
        10004e14 * 1.002
    )); // 1.002 = 1.0004^5
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));
    assertLe(maturityIndex, 10025e14);
    assertGe(maturityIndex, 10024e14);

    int256[] memory cashflows = new int256[](4);

    cashflows[0] = checkSettle(
        1, // accountId,
        vm.addr(1), // user
        1001e18, // deposited margin
        -(amounts[0].executedBaseAmount + amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[0].executedQuoteAmount + amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee1 + fee5,
        maturityIndex
    );
    
    cashflows[1] = checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount + amounts[2].executedBaseAmount,
        amounts[0].executedQuoteAmount + amounts[2].executedQuoteAmount,
        amounts[0].fee + amounts[2].fee,
        maturityIndex
    );

    cashflows[2] = checkSettle(
        3, // accountId,
        vm.addr(3), // user
        1001e18, // deposited margin
        -(amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount * 2 / 3),
        -(amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount * 2 / 3),
        fee3,
        maturityIndex
    );

    cashflows[3] = checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        maturityIndex
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); 

    // LPs
    assertLt(cashflows[0], 0, "0");
    assertLt(cashflows[2], 0, "2");

    /* cashflow ~= + 500 * ((1.0004^(365/0.5))^(1/365) - 1) 
                + 300 * ((1.0004^(365/0.5))^(1.5/365) - 1) 
                - 500 * (1.04^(1/365) - 1) 
                - 300 * (1.04^(1.5/365) - 1)
    */
    assertGt(cashflows[1], 0, "1");
    assertAlmostEq(cashflows[1], int256(658135400000000000), 5e16); //5% error

    // cashflow ~= + 500 * ((1.0004^(365/0.5))^(2/365) - 1) - 500 * (1.04^(2/365) - 1)
    assertGt(cashflows[3], 0, "3");
    assertAlmostEq(cashflows[3], int(693015000000000000), 5e16);

    assertAlmostEq(-(cashflows[0] + cashflows[2]), cashflows[1] + cashflows[3], 1000);

  }

  function test_full_unwinds_trader() public {
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP
    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004)); // 2 days till end

    // LP
    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); 
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004 * 1.0004)); // 1.5 days

    // LP BURN
    uint256 fee5 = editMaker(
        1, // accountId
        vm.addr(1), // user
        0, // toDeposit
        -5000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // UNWIND -> switch to FT
    amounts[2] = editTaker(
        2, // accountId
        vm.addr(2), // user
        0, // toDeposit
        -600e18 // baseAmount
    );

    vm.warp(maturityTimestamp + 1);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(
        10004e14 * 1.002
    )); // 1.002 = 1.0004^5
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));
    assertLe(maturityIndex, 10025e14);
    assertGe(maturityIndex, 10024e14);

    int256[] memory cashflows = new int256[](4);

    cashflows[0] = checkSettle(
        1, // accountId,
        vm.addr(1), // user
        1001e18, // deposited margin
        -(amounts[0].executedBaseAmount + amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount / 3),
        -(amounts[0].executedQuoteAmount + amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount / 3),
        fee1 + fee5,
        maturityIndex
    );
    
    cashflows[1] = checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount + amounts[2].executedBaseAmount,
        amounts[0].executedQuoteAmount + amounts[2].executedQuoteAmount,
        amounts[0].fee + amounts[2].fee,
        maturityIndex
    );

    cashflows[2] = checkSettle(
        3, // accountId,
        vm.addr(3), // user
        1001e18, // deposited margin
        -(amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount * 2 / 3),
        -(amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount * 2 / 3),
        fee3,
        maturityIndex
    );

    cashflows[3] = checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        maturityIndex
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); 

    // LPs
    assertLt(cashflows[0], 0, "0");
    assertGt(cashflows[2], 0, "2");

    /* cashflow ~= + 500 * ((1.0004^(365/0.5))^(1/365) - 1) 
                - 100 * ((1.0004^(365/0.5))^(1.5/365) - 1) 
                - 500 * (1.04^(1/365) - 1) 
                + 100 * (1.04^(1.5/365) - 1)
    */
    assertGt(cashflows[1], 0, "1");
    assertAlmostEq(cashflows[1], int256(242421800000000000), 5e16); //5% error

    // cashflow ~= + 500 * ((1.0004^(365/0.5))^(2/365) - 1) - 500 * (1.04^(2/365) - 1)
    assertGt(cashflows[3], 0, "3");
    assertAlmostEq(cashflows[3], int(693015000000000000), 5e16);

    assertAlmostEq(-(cashflows[0] + cashflows[2]), cashflows[1] + cashflows[3], 1000);
  }

  function test_full_unwinds_lp() public {
    setConfigs();

    ExecutedAmounts[] memory amounts = new ExecutedAmounts[](3);

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14)); // 2.5 days till end

    // LP
    uint256 fee1 = newMaker(
        1, // accountId
        vm.addr(1), // user
        1, // count,
        2, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[0] = newTaker(
        2, // accountId
        vm.addr(2), // user
        1, // count,
        3, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    vm.warp(block.timestamp + 43200); // advance by 0.5 days 

    int24 currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004)); // 2 days till end

    // LP
    uint256 fee3 = newMaker(
        3, // accountId
        vm.addr(3), // user
        1, // count,
        4, // merkleIndex
        1001e18, // toDeposit
        10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // VT
    amounts[1] = 
    newTaker(
        4, // accountId
        vm.addr(4), // user
        1, // count,
        5, // merkleIndex
        101e18, // toDeposit
        500e18 // baseAmount
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); 
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(10004e14 * 1.0004 * 1.0004)); // 1.5 days

    // LP BURN
    uint256 fee5 = editMaker(
        1, // accountId
        vm.addr(1), // user
        0, // toDeposit
        -10000e18, // baseAmount
        -14100, // 4.1%
        -13620 // 3.9% 
    );

    // UNWIND -> switch to FT
    amounts[2] = editTaker(
        2, // accountId
        vm.addr(2), // user
        0, // toDeposit
        -600e18 // baseAmount
    );

    vm.warp(maturityTimestamp + 1);
    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(
        10004e14 * 1.002
    )); // 1.002 = 1.0004^5
    datedIrsProxy.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

    int256 maturityIndex = int256(UD60x18.unwrap(datedIrsProxy.getRateIndexMaturity(marketId, maturityTimestamp)));
    assertLe(maturityIndex, 10025e14);
    assertGe(maturityIndex, 10024e14);

    int256[] memory cashflows = new int256[](4);

    cashflows[0] = checkSettle(
        1, // accountId,
        vm.addr(1), // user
        1001e18, // deposited margin
        -(amounts[0].executedBaseAmount + amounts[1].executedBaseAmount / 2),
        -(amounts[0].executedQuoteAmount + amounts[1].executedQuoteAmount / 2),
        fee1 + fee5,
        maturityIndex
    );
    
    cashflows[1] = checkSettle(
        2, // accountId,
        vm.addr(2), // user
        101e18, // deposited margin
        amounts[0].executedBaseAmount + amounts[2].executedBaseAmount,
        amounts[0].executedQuoteAmount + amounts[2].executedQuoteAmount,
        amounts[0].fee + amounts[2].fee,
        maturityIndex
    );

    cashflows[2] = checkSettle(
        3, // accountId,
        vm.addr(3), // user
        1001e18, // deposited margin
        -(amounts[1].executedBaseAmount / 2 + amounts[2].executedBaseAmount),
        -(amounts[1].executedQuoteAmount / 2 + amounts[2].executedQuoteAmount),
        fee3 + 1,
        maturityIndex
    );

    cashflows[3] = checkSettle(
        4, // accountId,
        vm.addr(4), // user
        101e18, // deposited margin
        amounts[1].executedBaseAmount,
        amounts[1].executedQuoteAmount,
        amounts[1].fee,
        maturityIndex
    );

    currentTick = vammProxy.getVammTick(marketId, maturityTimestamp);
    // console2.log("tick", currentTick); 

    // LPs
    assertLt(cashflows[0], 0, "0");
    assertGt(cashflows[2], 0, "2");

    /* cashflow ~= + 500 * ((1.0004^(365/0.5))^(1/365) - 1) 
                - 100 * ((1.0004^(365/0.5))^(1.5/365) - 1) 
                - 500 * (1.04^(1/365) - 1) 
                + 100 * (1.04^(1.5/365) - 1)
    */
    assertGt(cashflows[1], 0, "1");
    assertAlmostEq(cashflows[1], int256(242421800000000000), 5e16); //5% error

    // cashflow ~= + 500 * ((1.0004^(365/0.5))^(2/365) - 1) - 500 * (1.04^(2/365) - 1)
    assertGt(cashflows[3], 0, "3");
    assertAlmostEq(cashflows[3], int(693015000000000000), 5e16);

    assertAlmostEq(-(cashflows[0] + cashflows[2]), cashflows[1] + cashflows[3], 1000);
  }
}
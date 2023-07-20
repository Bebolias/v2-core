pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {SetupProtocol, IRateOracle, VammConfiguration, Utils, AccessPassNFT} from "../../src/utils/SetupProtocol.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import "./TestUtils.sol";
import {Merkle} from "murky/Merkle.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

import {SetUtil} from "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";
import {SafeCastI256, SafeCastU256, SafeCastU128} from "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";

import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";

contract ScenarioHelper is Test, SetupProtocol, TestUtils {
    using SetUtil for SetUtil.Bytes32Set;
    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;
    using SafeCastU128 for uint128;

    struct TraderActor {
        address walletAddress;
        uint128 accountId;
    }

    struct LpActor {
        address walletAddress;
        uint128 accountId;
        int24 tickLower;
        int24 tickUpper;
    }

    address owner = address(999999);
    ERC20Mock token = new ERC20Mock(6);
    DeployProtocol deployProtocol = new DeployProtocol(owner, address(token));
    SetUtil.Bytes32Set addressPassNftInfo;

    Merkle merkle = new Merkle();

    constructor() SetupProtocol(
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
            echidna: false,
            broadcast: false,
            prank: true
        }),
        owner
    ){}

    function redeemAccessPass(address user, uint256 count, uint256 merkleIndex) public {
        metadata.accessPassNft.redeem(
            user,
            count,
            merkle.getProof(addressPassNftInfo.values(), merkleIndex),
            merkle.getRoot(addressPassNftInfo.values())
        );
    }

    function setUpAccessPassNft(address[] memory owners) public {
        for (uint256 i = 0; i < owners.length; i++) {
            addressPassNftInfo.add(keccak256(abi.encodePacked(owners[i], uint256(1))));
        }
        addNewRoot(
            AccessPassNFT.RootInfo({
                merkleRoot: merkle.getRoot(addressPassNftInfo.values()),
                baseMetadataURI: "ipfs://"
            })
        );
    }

    struct TakerExecutedAmounts {
        uint256 depositedAmount;
        int256 executedBaseAmount;
        int256 executedQuoteAmount;
        uint256 fee;
        uint256 im;
        // todo: add highestUnrealizedLoss
        // todo: can we pull more information to play with in tests?
    }

    struct MakerExecutedAmounts {
        int256 baseAmount;
        uint256 depositedAmount;
        int24 tickLower;
        int24 tickUpper;
        uint256 fee;
        uint256 im;
        // todo: add highestUnrealizedLoss
        // todo: can we pull more information to play with in tests?
    }

    function executeMakerOrder(
        uint128 _marketId,
        uint32 _maturityTimestamp,
        uint128 accountId,
        address user,
        uint256 count,
        uint256 merkleIndex,
        uint256 margin,
        int256 baseAmount,
        int24 tickLower,
        int24 tickUpper
    ) public returns (MakerExecutedAmounts memory){
        changeSender(user);

        token.mint(user, margin);

        // note: merkleIndex = 0 is a flag for edit position,
        // only owner had index 0
        if ( merkleIndex != 0 ) {
            redeemAccessPass(user, count, merkleIndex);
        }

        // PERIPHERY LP COMMAND
        int256 liquidityIndex = UD60x18.unwrap(contracts.aaveV3RateOracle.getCurrentIndex()).toInt();

        bytes memory output = mintOrBurn(MintOrBurnParams({
            marketId: _marketId,
            tokenAddress: address(token),
            accountId: accountId,
            maturityTimestamp: _maturityTimestamp,
            marginAmount: margin,
            notionalAmount: baseAmount * liquidityIndex / 1e18,
            tickLower: tickLower, // 4.67%
            tickUpper: tickUpper, // 2.35%
            rateOracleAddress: address(contracts.aaveV3RateOracle)
        }));

        (
            uint256 fee,
            uint256 im
        ) = abi.decode(output, (uint256, uint256));

        return MakerExecutedAmounts({
            baseAmount: baseAmount,
            depositedAmount: margin,
            tickLower: tickLower,
            tickUpper: tickUpper,
            fee: fee,
            im: im
        });
    }

    function executeTakerOrder(
        uint128 _marketId,
        uint32 _maturityTimestamp,
        uint128 accountId,
        address user,
        uint256 count,
        uint256 merkleIndex,
        uint256 margin,
        int256 baseAmount
    ) public returns (TakerExecutedAmounts memory executedAmounts) {
        changeSender(user);

        // todo: if liquidation booster > 0, mint margin + liqBooster - liqBoosterBalance
        token.mint(user, margin);

        // note: merkleIndex = 0 is a flag for edit position,
        // only owner had index 0
        if ( merkleIndex != 0 ) {
            redeemAccessPass(user, count, merkleIndex);
        }

        int256 liquidityIndex = UD60x18.unwrap(contracts.aaveV3RateOracle.getCurrentIndex()).toInt();

        bytes memory output = swap({
            marketId: _marketId,
            tokenAddress: address(token),
            accountId: accountId,
            maturityTimestamp: _maturityTimestamp,
            marginAmount: margin,
            notionalAmount: baseAmount * liquidityIndex / 1e18,  // positive means VT, negative means FT
            rateOracleAddress: address(contracts.aaveV3RateOracle)
        });

        // todo: add unrealized loss to exposures
        (
            executedAmounts.executedBaseAmount,
            executedAmounts.executedQuoteAmount,
            executedAmounts.fee, 
            executedAmounts.im,,
        ) = abi.decode(output, (int256, int256, uint256, uint256, uint256, int24));

        executedAmounts.depositedAmount = margin;
    }
    struct MarginData {
        bool liquidatable;
        uint256 initialMarginRequirement;
        uint256 liquidationMarginRequirement;
        uint256 highestUnrealizedLoss;
    }

    struct UnfilledData {
        uint256 unfilledBaseLong;
        uint256 unfilledQuoteLong;
        uint256 unfilledBaseShort;
        uint256 unfilledQuoteShort;
    }

    struct CheckImParams {
        uint128 _marketId;
        uint32 _maturityTimestamp;
        uint128 accountId;
        address user;
        int256 _filledBase;
        MakerExecutedAmounts makerAmounts;
        TakerExecutedAmounts takerAmounts;
        uint256 twap;
    }

    function checkImMaker(
        CheckImParams memory p
    ) public returns (MarginData memory m, UnfilledData memory u){

        uint256[] memory externalParams = new uint256[](3);
        externalParams[0] = UD60x18.unwrap(contracts.aaveV3RateOracle.getCurrentIndex());
        externalParams[1] = UD60x18.unwrap(contracts.coreProxy.getMarketRiskConfiguration(1, p._marketId).riskParameter);
        externalParams[2] = UD60x18.unwrap(contracts.coreProxy.getProtocolRiskConfiguration().imMultiplier);

        (
            m.liquidatable,
            m.initialMarginRequirement,
            m.liquidationMarginRequirement,
            m.highestUnrealizedLoss
        ) = contracts.coreProxy.isLiquidatable(p.accountId, address(token));

        // console2.log("liquidatable", m.liquidatable);
        // console2.log("initialMarginRequirement", m.initialMarginRequirement);
        // console2.log("liquidationMarginRequirement", m.liquidationMarginRequirement);
        // console2.log("highestUnrealizedLoss",m.highestUnrealizedLoss);

        (u.unfilledBaseLong, u.unfilledBaseShort, u.unfilledQuoteLong, u.unfilledQuoteShort) =
            contracts.vammProxy.getAccountUnfilledBaseAndQuote(p._marketId, p._maturityTimestamp, p.accountId);

        // console2.log("unfilledBaseLong", u.unfilledBaseLong);
        // console2.log("unfilledQuoteLong", u.unfilledQuoteLong);
        // console2.log("unfilledBaseShort", u.unfilledBaseShort);
        // console2.log("unfilledQuoteShort", u.unfilledQuoteShort);

        assertEq(uint256(p.makerAmounts.baseAmount), u.unfilledBaseLong+u.unfilledBaseShort + 1, "unfilledBase");
        assertEq(m.liquidatable, false, "liquidatable");
        assertGe(m.initialMarginRequirement, m.liquidationMarginRequirement, "lmr");

        // calculate LMRLow
        uint256 baseLower = absUtil(p._filledBase - u.unfilledBaseShort.toInt());
        uint256 baseUpper = absUtil(p._filledBase + u.unfilledBaseLong.toInt());
        // todo: replace 1 with protocolId
        uint256 expectedLmrLower = (externalParams[1] * baseLower) * externalParams[0] * timeFactor(p._maturityTimestamp) / 1e54;
        uint256 expectedLmrUpper = (externalParams[1] * baseUpper) * externalParams[0] * timeFactor(p._maturityTimestamp) / 1e54;

        // console2.log("baseLower", baseLower);
        // console2.log("baseUpper", baseUpper);
        // console2.log("expectedLmrLower", expectedLmrLower);
        // console2.log("expectedLmrUpper", expectedLmrUpper);

        // calculate unrealized loss low
        uint256 unrealizedLossLower = absOrZero(u.unfilledQuoteShort.toInt() - 
            (baseLower * externalParams[0] * (p.twap * timeFactor(p._maturityTimestamp) / 1e18 + 1e18) / 1e36).toInt());
        uint256 unrealizedLossUpper = absOrZero(-u.unfilledQuoteLong.toInt() + 
            (baseUpper * externalParams[0] * (p.twap * timeFactor(p._maturityTimestamp) / 1e18 + 1e18) / 1e36).toInt());
        // console2.log("unrealizedLossLower", unrealizedLossLower);
        // console2.log("unrealizedLossUpper", unrealizedLossUpper);

        // todo: manually calculate liquidation margin requirement for lower and upper scenarios and compare to the above
        uint256 expectedUnrealizedLoss = unrealizedLossLower + expectedLmrLower >  unrealizedLossUpper + expectedLmrUpper ?
            unrealizedLossLower :
            unrealizedLossUpper;
        uint256 expectedLmr = unrealizedLossLower + expectedLmrLower >  unrealizedLossUpper + expectedLmrUpper ?
            expectedLmrLower :
            expectedLmrUpper;

        assertEq(expectedUnrealizedLoss, m.highestUnrealizedLoss, "expectedUnrealizedLoss");
        assertAlmostEq(expectedLmr, m.liquidationMarginRequirement, 1e5);
        assertAlmostEq(expectedLmr * externalParams[2], m.initialMarginRequirement, 1e5);
        assertGt(p.makerAmounts.depositedAmount, expectedLmr * externalParams[2] + expectedUnrealizedLoss, "IMR");
    }

    function checkImTaker(
        CheckImParams memory p
    ) public returns (MarginData memory m, UnfilledData memory u){

        uint256 currentLiquidityIndex = UD60x18.unwrap(contracts.aaveV3RateOracle.getCurrentIndex());

        (
            m.liquidatable,
            m.initialMarginRequirement,
            m.liquidationMarginRequirement,
            m.highestUnrealizedLoss
        ) = contracts.coreProxy.isLiquidatable(p.accountId, address(token));

        // console2.log("liquidatable", m.liquidatable);
        // console2.log("initialMarginRequirement", m.initialMarginRequirement);
        // console2.log("liquidationMarginRequirement", m.liquidationMarginRequirement);
        // console2.log("highestUnrealizedLoss",m.highestUnrealizedLoss);

        (u.unfilledBaseLong, u.unfilledBaseShort, u.unfilledQuoteLong, u.unfilledQuoteShort) =
            contracts.vammProxy.getAccountUnfilledBaseAndQuote(p._marketId, p._maturityTimestamp, p.accountId);

        assertEq(0, u.unfilledBaseLong);
        assertEq(0, u.unfilledQuoteLong);
        assertEq(0, u.unfilledBaseShort);
        assertEq(0, u.unfilledQuoteShort);

        // assertEq(m.liquidatable, false, "liquidatable");
        assertGe(m.initialMarginRequirement, m.liquidationMarginRequirement, "lmr");

        // calculate LMR
        // todo: replace 1 with protocolId
        uint256 riskParam = UD60x18.unwrap(contracts.coreProxy.getMarketRiskConfiguration(1, p._marketId).riskParameter);
        uint256 expectedLmr = (riskParam * absUtil(p.takerAmounts.executedBaseAmount)) * currentLiquidityIndex * timeFactor(p._maturityTimestamp) / 1e54;
        // console2.log("expectedLmr", expectedLmr);

        // calculate unrealized loss low
        uint256 expectedUnrealizedLoss = absOrZero(p.takerAmounts.executedQuoteAmount + 
            (p.takerAmounts.executedBaseAmount * currentLiquidityIndex.toInt() * (p.twap * timeFactor(p._maturityTimestamp) / 1e18 + 1e18).toInt() / 1e36));

        // console2.log("expectedUnrealizedLoss", expectedUnrealizedLoss);
        uint256 imMultiplier = UD60x18.unwrap(contracts.coreProxy.getProtocolRiskConfiguration().imMultiplier);
        assertAlmostEq(expectedUnrealizedLoss.toInt(), m.highestUnrealizedLoss.toInt(), 1e5);
        assertAlmostEq(expectedLmr, m.liquidationMarginRequirement, 1e5);
        assertAlmostEq(expectedLmr * imMultiplier, m.initialMarginRequirement, 1e5);
        assertGt(p.takerAmounts.depositedAmount, expectedLmr * imMultiplier + expectedUnrealizedLoss, "IMR taker");
    }

    function compareCurrentMarginData(uint128 accountId, MarginData memory m, bool higherHul) 
        public returns (MarginData memory mCurrent) {
        mCurrent = getMarginData(accountId);

        assertEq(mCurrent.liquidatable, m.liquidatable, "liquidatable");
        assertEq(mCurrent.initialMarginRequirement, m.initialMarginRequirement, "IMR");
        assertEq(mCurrent.liquidationMarginRequirement, m.liquidationMarginRequirement, "LMR");

        if (higherHul) {
            assertGt(mCurrent.highestUnrealizedLoss, m.highestUnrealizedLoss, "highestUnrealizedLoss");
        } else {
            assertLt(mCurrent.highestUnrealizedLoss, m.highestUnrealizedLoss, "highestUnrealizedLoss");
        }
    }

    function getMarginData(uint128 accountId) public view returns (MarginData memory m) {
        (
            m.liquidatable,
            m.initialMarginRequirement,
            m.liquidationMarginRequirement,
            m.highestUnrealizedLoss
        ) = contracts.coreProxy.isLiquidatable(accountId, address(token));
    }

    function checkSettle(
        uint128 marketId,
        uint32 maturityTimestamp,
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
        settlementCashflow = executedBaseAmount * maturityIndex / 1e18 + executedQuoteAmount;
        // fee = annualizedNotional * atomic fee
        int256 existingCollateral = initialDeposit - fee.toInt();

        settle(
            marketId,
            maturityTimestamp,
            accountId,
            user,
            settlementCashflow,
            existingCollateral
        );

        uint256 collateralBalance = contracts.coreProxy.getAccountCollateralBalance(accountId, address(token));

        uint256 userBalanceAfterSettle = token.balanceOf(user);
        // console2.log(accountId);
        assertEq(collateralBalance, 0);
        assertEq(userBalanceAfterSettle.toInt(), userBalanceBeforeSettle.toInt() + settlementCashflow + existingCollateral);
    }

    // todo: duplicate with settleAccount below
    function settle(
        uint128 marketId,
        uint32 maturityTimestamp,
        uint128 accountId,
        address user,
        int256 settlementCashflow,
        int256 existingCollateral
    ) public {
        changeSender(user);
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
        periphery_execute(commands, inputs, block.timestamp + 1);
    }

    function getCollateralBalance(uint128 accountId) public view returns (uint256 balance) {
        return contracts.coreProxy.getAccountCollateralBalance(accountId, address(token));
    }

    function closeAccount(address user, uint128 accountId) public {
        vm.prank(user);
        contracts.datedIrsProxy.closeAccount(accountId, address(token));
    }

    // todo: duplicate with executeMakerOrder above
    function editExecuteMakerOrder(
        uint128 _marketId,
        uint32 _maturityTimestamp,
        uint128 accountId,
        address user,
        uint256 margin,
        int256 baseAmount,
        int24 tickLower,
        int24 tickUpper
    ) public returns (MakerExecutedAmounts memory){
        changeSender(user);

        int256 liquidityIndex = UD60x18.unwrap(contracts.aaveV3RateOracle.getCurrentIndex()).toInt();

        bytes memory output = mintOrBurn(MintOrBurnParams({
            marketId: _marketId,
            tokenAddress: address(token),
            accountId: accountId,
            maturityTimestamp: _maturityTimestamp,
            marginAmount: margin,
            notionalAmount: baseAmount * liquidityIndex / 1e18,
            tickLower: tickLower,
            tickUpper: tickUpper,
            rateOracleAddress: address(contracts.aaveV3RateOracle)
        }));

        (
            uint256 fee,
            uint256 im
        ) = abi.decode(output, (uint256, uint256));

        return MakerExecutedAmounts({
            baseAmount: baseAmount,
            depositedAmount: margin,
            tickLower: tickLower,
            tickUpper: tickUpper,
            fee: fee,
            im: im
        });
    }

    // todo: duplicate with executeTakerOrder above
    function editExecuteTakerOrder(
        uint128 _marketId,
        uint32 _maturityTimestamp,
        uint128 accountId,
        address user,
        uint256 margin,
        int256 baseAmount
    ) public returns (TakerExecutedAmounts memory executedAmounts) {
        changeSender(user);

        int256 liquidityIndex = UD60x18.unwrap(contracts.aaveV3RateOracle.getCurrentIndex()).toInt();

        bytes memory output = swap({
            marketId: _marketId,
            tokenAddress: address(token),
            accountId: accountId,
            maturityTimestamp: _maturityTimestamp,
            marginAmount: margin,
            notionalAmount: baseAmount * liquidityIndex / 1e18, 
            rateOracleAddress: address(contracts.aaveV3RateOracle)
        });

        (
            executedAmounts.executedBaseAmount,
            executedAmounts.executedQuoteAmount,
            executedAmounts.fee, 
            executedAmounts.im,,
        ) = abi.decode(output, (int256, int256, uint256, uint256, uint256, int24));

        executedAmounts.depositedAmount = margin;
    }

    // todo: duplicate with settle function above
    function settleAccount(address user, uint128 accountId, uint128 marketId, uint32 maturityTimestamp) public {
        bytes memory commands;
        bytes[] memory inputs;
        commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)));
        inputs = new bytes[](1);

        inputs[0] = abi.encode(accountId, marketId, maturityTimestamp);

        changeSender(user);
        periphery_execute(commands, inputs, block.timestamp + 100);  
    }

    function liquidateAccount(address user, uint128 liquidatorAccountId, uint128 accountId) public {
        vm.prank(user);
        contracts.coreProxy.liquidate(accountId, liquidatorAccountId, address(token));
    }
}
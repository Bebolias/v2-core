pragma solidity >=0.8.19;

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";

import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import {Time} from "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

import "forge-std/console2.sol";

contract Scenario1 is ScenarioHelper {
    uint32 maturityTimestamp; // 1 year pool
    uint128 marketId = 1;

    function setUp() public {
        // COMPLETE WITH ACTORS' ADDRESSES
        address[] memory accessPassOwners = new address[](7);
        accessPassOwners[0] = owner; // note: do not change owner's index 0
        accessPassOwners[1] = address(1); // LP
        accessPassOwners[2] = address(2); // VT
        accessPassOwners[3] = address(3); // FT
        accessPassOwners[4] = address(4); // LP
        accessPassOwners[5] = address(5); // VT
        accessPassOwners[6] = address(6); // FT
        setUpAccessPassNft(accessPassOwners);
        redeemAccessPass(owner, 1, 0);

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
            // note, let's keep as bridged usdc for now
            tokenAddress: address(token),
            productId: 1,
            marketId: marketId,
            feeCollectorAccountId: 999,
            liquidationBooster: 0,
            cap: 100000e6,
            atomicMakerFee: ud60x18(0),
            atomicTakerFee: ud60x18(0.0002e18),
            riskParameter: ud60x18(0.013e18),
            twapLookbackWindow: 259200,
            maturityIndexCachingWindowInSeconds: 3600
        });
        vm.warp(1688166000); 
        uint32[] memory times = new uint32[](2);
        times[0] = uint32(block.timestamp - 86400*4); // note goes back 4 days, while lookback is 3 days, so should be fine?
        times[1] = uint32(block.timestamp - 86400*3);
        int24[] memory observedTicks = new int24[](2);
        observedTicks[0] = -12240; // 3.4% note worth double checking
        observedTicks[1] = -12240; // 3.4%
        maturityTimestamp = uint32(block.timestamp + Time.SECONDS_IN_YEAR);
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

        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18));
    }

    function test_happy_path_VT_profit() public {
        TakerExecutedAmounts[] memory takers = new TakerExecutedAmounts[](4);
        MakerExecutedAmounts[] memory makers = new MakerExecutedAmounts[](2);

        MarginData[] memory margin = new MarginData[](6);

        // FIRST TRADERS ENTRY
        {
            makers[0] = executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 1,
                user: address(1),
                count: 1,
                merkleIndex: 1, // NEW maker
                margin: 1000e6,
                baseAmount: 10000e6,
                tickLower: -13920, // 4.02261%
                tickUpper: -10260 // 2.80092%
            });

            margin[0] = getMarginData(1);

            // VT
            takers[0] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 2,
                user: address(2),
                count: 1,
                merkleIndex: 2, // NEW taker
                margin: 110e6,
                baseAmount: 600e6
            });

            margin[1] = getMarginData(2);

            // FT
            takers[1] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 3,
                user: address(3),
                count: 1,
                merkleIndex: 3, // NEW taker
                margin: 60e6,
                baseAmount: -100e6
            });

            margin[2] = getMarginData(3);
        }

        // VERIFY MARGIN DATA AFTER SWAPS
        {
            //LP 
            // currentTick = -12426 // console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent))
             = 0.013 * (-500e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12426)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 73_289_773
             LMR Short = riskParam * (filledB - liq * (sqrtCurrent - sqrtLow)) = 56_710_226
            */

            // unfilledBaseShort 3862325112
            // unfilledBaseLong 6137674887
            // console2.log(takers[0].executedQuoteAmount); // -621231883
            // console2.log(takers[1].executedQuoteAmount); // 103370686
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = ((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12426)))/100 - 0.001 + 1) * -6137674887
                = 6_322_346_487
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = (-103_370_686 + 621_231_883) - 6_322_346_487 + 73_289_773/0.013 * (0.034005555117321891 - 0.001  + 1)
                = 19264185 (upnl positive)

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = ((1/(sqrt(1.0001^-12426) * sqrt(1.0001^-13920)))/100 + 0.001 + 1) * 3862325112
                = 4_010_371_196
            HUL Short = filledQuote + unfilledQuoteShort + (filledB + unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = (-103_370_686 + 621_231_883) + 4_010_371_196 - 56_710_226/0.013 * (0.034005555117321891 + 0.001  + 1)
                = 13201668 (upnl positive)
            */

            assertEq(margin[0].liquidationMarginRequirement, 73272070, "Maths LMR LP");
            assertEq(margin[0].initialMarginRequirement, 109908105, "Maths IMR LP");
            assertEq(margin[0].highestUnrealizedLoss, 0, "Maths HUL LP");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = riskParam * (filledB )
             = 0.013 * 600e6
             = 7800000
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -621231883  + 600000000 * (0.034005555117321891 - 0.001  + 1)
                = -1428550 (upnl)
            */

            assertEq(margin[1].liquidationMarginRequirement, 7800000, "Maths LMR VT");
            assertEq(margin[1].initialMarginRequirement, 11700000, "Maths IMR VT");
            assertEq(margin[1].highestUnrealizedLoss, 1428550, "Maths HUL VT");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = riskParam * (filledB )
             = 0.013 * -100e6
             = 1300000
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 103370686  - 100000000 * (0.034005555117321891 + 0.001  + 1)
                = -129869 (upnl)
            */

            assertEq(margin[2].liquidationMarginRequirement, 1300000, "Maths LMR FT");
            assertEq(margin[2].initialMarginRequirement, 1950000, "Maths IMR FT");
            assertEq(margin[2].highestUnrealizedLoss, 129869, "Maths HUL FT");
            
        }

        // // print twap = 0.034005555117321891
        // uint256 twap = UD60x18.unwrap(contracts.vammProxy.getDatedIRSTwap(marketId, maturityTimestamp, 0, 259200, false, false));
        // console2.log("TWAP after swaps", twap);

        // ADVANCE TIME 0.5 years
        vm.warp(block.timestamp + 365 * 12 * 60 * 60);

        // twap 0.034643945147052780
        // uint256 twap = UD60x18.unwrap(contracts.vammProxy.getDatedIRSTwap(marketId, maturityTimestamp, 0, 259200, false, false));
        // console2.log("TWAP after time elapsed", twap);
        // TWAP increased as effect of VT direction over time

        // CHECK EFFECTS
        {
            //LP 
            // currentTick = -12426 // console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent))
             = 0.013 * 1/2 * (-500e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12426)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 36_644_886
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
                = -28_355_113
            */

            // unfilledBaseShort 3862325112
            // unfilledBaseLong 6137674887
            // console2.log(takers[0].executedQuoteAmount); // -621231883
            // console2.log(takers[1].executedQuoteAmount); // 103370686
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12426)))/100 - 0.001)*1/2 + 1) * -6137674887
                = 6_230_001_068
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = (-103_370_686 + 621_231_883) - 6_230_001_068 + 36_644_886 * 2 /0.013 * ((0.034643945147052780 - 0.001)*1/2  + 1)
                = 20_371_708 (upnl positive)

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12426) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 3862325112
                = 3_936_348_154
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = (-103_370_686 + 621_231_883) + 3_936_348_154 - 28_355_113 * 2 /0.013 * ((0.034643945147052780 + 0.001)*1/2  + 1)
                = 14_139_036 (upnl positive)
            */
            MarginData memory marginAfterTime = getMarginData(1);
            assertEq(marginAfterTime.liquidationMarginRequirement, 36644886, "Maths LMR LP after time");
            assertEq(marginAfterTime.initialMarginRequirement, 54967329, "Maths IMR LP after time");
            assertEq(marginAfterTime.highestUnrealizedLoss, 0, "Maths HUL LP after time");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = riskParam * (filledB) / 2
             = 0.013 * 600e6
             = 7800000 / 2 = 3900000 
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -621231883  + 600000000 * ((0.034643945147052780 - 0.001)/2  + 1)
                = -11138699 (upnl)
            */

            marginAfterTime = getMarginData(2);
            assertEq(marginAfterTime.liquidationMarginRequirement, 3900000, "Maths LMR VT");
            assertEq(marginAfterTime.initialMarginRequirement, 5850000, "Maths IMR VT");
            assertEq(marginAfterTime.highestUnrealizedLoss, 11138700, "Maths HUL VT");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = riskParam * (filledB )
             = 0.013 * -100e6 / 2
             = 650000
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 103370686  - 100000000 * ((0.034643945147052780 + 0.001)/2  + 1)
                = 1588488
            */

            marginAfterTime = getMarginData(3);
            assertEq(marginAfterTime.liquidationMarginRequirement, 650000, "Maths LMR FT");
            assertEq(marginAfterTime.initialMarginRequirement, 975000, "Maths IMR FT");
            assertEq(marginAfterTime.highestUnrealizedLoss, 0, "Maths HUL FT");

            // console2.log("LMR", margin[0].liquidationMarginRequirement);
            // (,,uint256 unfilledQuoteLong,) =
            //     contracts.vammProxy.getAccountUnfilledBaseAndQuote(marketId, maturityTimestamp, 1);

            // console2.log(unfilledQuoteLong);
            
        }

        // set index apy -> 10%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.05e18));

        {
            //LP 
            // currentTick = -12426 // console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent)) * li * timeFact
             = 0.013 * 1/2 * 1.05 * (-500e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12426)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 38477131
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
                = -29772868
            */

            // unfilledBaseShort 3862325112
            // unfilledBaseLong 6137674887
            // console2.log(takers[0].executedQuoteAmount); // -621231883
            // console2.log(takers[1].executedQuoteAmount); // 103370686
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12426)))/100 - 0.001)*1/2 + 1) * 1.05 * -6137674887
                = -6541511221
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = (-103370686 + 621231883) - 6541511221 + (38477131 * 2 /0.013) * ((0.034643945147052780 - 0.001)*1/2  + 1)
                = -4512755

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12426) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 1.05 * 3862325112
                = 4133165562
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = (-103370686 + 621231883) + 3956029895 - (-29772868 * 2 /0.013) * ((0.034643945147052780 + 0.001)*1/2  + 1)
                = 9135964820
            */
            MarginData memory marginAfterIndex = getMarginData(1);
            assertEq(marginAfterIndex.liquidationMarginRequirement, 38477131, "Maths LMR LP index growth");
            assertEq(marginAfterIndex.initialMarginRequirement, 57715696, "Maths IMR index growth");
            assertEq(marginAfterIndex.highestUnrealizedLoss, 4512742, "Maths HUL LP index growth");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * 600e6 / 2 * 1.05
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -621231883  + 600000000 * 1.05 * ((0.034643945147052780 - 0.001)/2  + 1)
                = 19365959
            */

            marginAfterIndex = getMarginData(2);
            assertEq(marginAfterIndex.liquidationMarginRequirement, 4095000, "Maths LMR VT index growth");
            assertEq(marginAfterIndex.initialMarginRequirement, 6142500, "Maths IMR VT index growth");
            assertEq(marginAfterIndex.highestUnrealizedLoss, 0, "Maths HUL VT index growth");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * -100e6 / 2 * 1.05
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 103370686  - 100000000 * 1.05 * ((0.034643945147052780 + 0.001)/2  + 1)
                = -3500621
            */

            marginAfterIndex = getMarginData(3);
            assertEq(marginAfterIndex.liquidationMarginRequirement, 682500, "Maths LMR FT index growth");
            assertEq(marginAfterIndex.initialMarginRequirement, 1023750, "Maths IMR FT index growth");
            assertEq(marginAfterIndex.highestUnrealizedLoss, 3500621, "Maths HUL FT index growth");

            // console2.log("LMR", margin[0].liquidationMarginRequirement);
            // (,,uint256 unfilledQuoteLong,) =
            //     contracts.vammProxy.getAccountUnfilledBaseAndQuote(marketId, maturityTimestamp, 1);

            // console2.log(unfilledQuoteLong);
            
        }

        // NEW TRADERS ENTRY
        {
            makers[1] = executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 4,
                user: address(4),
                count: 1,
                merkleIndex: 4, // NEW maker
                margin: 1000e6,
                baseAmount: 10000e6,
                tickLower: -13920, // 4.02261%
                tickUpper: -10260 // 2.80092%
            });

            margin[3] = getMarginData(4);

            // VT
            takers[2] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 5,
                user: address(5),
                count: 1,
                merkleIndex: 5, // NEW taker
                margin: 110e6,
                baseAmount: 600e6
            });

            margin[4] = getMarginData(5);

            // FT
            takers[3] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 6,
                user: address(6),
                count: 1,
                merkleIndex: 6, // NEW taker
                margin: 10e6,
                baseAmount: -100e6
            });

            margin[5] = getMarginData(6);
        }

        // NEW positions check
        uint256 twap = UD60x18.unwrap(contracts.vammProxy.getDatedIRSTwap(marketId, maturityTimestamp, 0, 259200, false, false));
        console2.log("TWAP after second trades", twap); // 34643945147052780
        {
            //LP 
            // currentTick = -12519
             console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent)) * li * timeFact
             = 0.013 * 1/2 * 1.05 * (-250e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12519)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 41882382
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
                = -26367617
            */

            // unfilledBaseShort 4112423206
            // unfilledBaseLong 5887576793
            // console2.log(takers[2].executedQuoteAmount); // -641288635
            // console2.log(takers[3].executedQuoteAmount); // 106784999
            // filledQuote LP = 267251818
            
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12519)))/100 - 0.001)*1/2 + 1) * 1.05 * -5887576793
                = -6275405446
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = (-106784999 + 641288635)/2 - 6275405446 + (41882382 * 2 /0.013) * ((0.034643945147052780 - 0.001)*1/2  + 1)

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12519) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 1.05 * 4112423206
                = 4401177089
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = (-106784999 + 641288635)/2 + 4401177089 - (-26367617 * 2 /0.013) * ((0.034643945147052780+ 0.001)*1/2  + 1)
            */
            MarginData memory margin2 = getMarginData(4);
            assertEq(margin2.liquidationMarginRequirement, 41882382, "Maths LMR LP 2");
            assertEq(margin2.highestUnrealizedLoss, 0, "Maths HUL LP 2");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * 600e6 / 2 * 1.05
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -641288635  + 600000000 * 1.05 * ((0.034643945147052780 - 0.001)/2  + 1)
                = -690792
            */

            margin2 = getMarginData(5);
            assertEq(margin2.liquidationMarginRequirement, 4095000, "Maths LMR VT 2");
            assertEq(margin2.highestUnrealizedLoss, 690793, "Maths HUL VT 2");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * -100e6 / 2 * 1.05
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 106784999  - 100000000 * 1.05 * ((0.034643945147052780 + 0.001)/2  + 1)
                = -86308
            */

            margin2 = getMarginData(6);
            assertEq(margin2.liquidationMarginRequirement, 682500, "Maths LMR FT index growth");
            assertEq(margin2.highestUnrealizedLoss, 86308, "Maths HUL FT index growth");
            
        }

        {
            //LP 
            // currentTick = -12519 // console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent))
             = 0.013 * 1/2 * 1.05 * (-750e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12519)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 38469882
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
                = -19542617
            */

            // unfilledBaseShort 3613387217
            // unfilledBaseLong 6386612782
            // console2.log(takers[0].executedQuoteAmount); // -621231883
            // console2.log(takers[1].executedQuoteAmount); // 103370686
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12519)))/100 - 0.001)*1/2 + 1) * 1.05 * -6386612782
                = -6807314120
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = 785_113_015 - 6_807_314_120 + 38_469_882 * 2 /0.013 * ((0.034643945147052780 - 0.001)*1/2  + 1)
                = -4197828

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12519) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 1.05 * 3613387217
                = 3867101278
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = 785_113_015 + 3867101278 - 19_542_617 * 2 /0.013 * ((0.034643945147052780 + 0.001)*1/2  + 1)
                = 1592075064

            */
            MarginData memory margin2 = getMarginData(1);
            assertEq(margin2.liquidationMarginRequirement, 38469882, "Maths LMR LP 2");
            assertEq(margin2.highestUnrealizedLoss, 4197793, "Maths HUL LP 2");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * 600e6 / 2 * 1.05
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -621231883  + 600000000 * 1.05 * ((0.034643945147052780 - 0.001)/2  + 1)
                = 19365959
            */

            margin2 = getMarginData(2);
            assertEq(margin2.liquidationMarginRequirement, 4095000, "Maths LMR VT index growth");
            assertEq(margin2.initialMarginRequirement, 6142500, "Maths IMR VT index growth");
            assertEq(margin2.highestUnrealizedLoss, 0, "Maths HUL VT index growth");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * -100e6 / 2 * 1.05
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 103370686  - 100000000 * 1.05 * ((0.034643945147052780 + 0.001)/2  + 1)
                = -3500621
            */

            margin2 = getMarginData(3);
            assertEq(margin2.liquidationMarginRequirement, 682500, "Maths LMR FT index growth");
            assertEq(margin2.initialMarginRequirement, 1023750, "Maths IMR FT index growth");
            assertEq(margin2.highestUnrealizedLoss, 3500621, "Maths HUL FT index growth");
            
        }

        vm.warp(block.timestamp + 365 * 12 * 60 * 60 + 1);
        // set index apy -> 10%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.1e18));

        // SETTLE
        {
            int256[] memory cashflows = new int256[](6);

            // LP 1
            console2.log(makers[0].fee);
            cashflows[0] = checkSettle(
                marketId,
                maturityTimestamp,
                1, // accountId,
                vm.addr(1), // user
                1000e6 - 1, // deposited margin
                -(
                    takers[0].executedBaseAmount +
                    takers[1].executedBaseAmount +
                    takers[2].executedBaseAmount / 2 +
                    takers[3].executedBaseAmount / 2
                ),
                -(
                    takers[0].executedQuoteAmount +
                    takers[1].executedQuoteAmount +
                    takers[2].executedQuoteAmount / 2 +
                    takers[3].executedQuoteAmount / 2
                ),
                makers[0].fee, // fee
                1.1e18 // liquidityindex
            );
            /* cashflow ~=
            ( + 500 * ((1.03464)^(1/2) - 1)
                + 750 * ((1.034967)^(1/2) - 1)
                - 500 * (1.05 - 1) 
                - 750 * (1.05 - 1)
            ) + (600 + 300) * 0.001
             */
            assertEq(makers[0].fee, 0);
            assertLt(cashflows[0], 0);
            assertAlmostEq(cashflows[0], -39863765, absUtil(cashflows[0] / 100)); // 1% diff

            // VT 1
            cashflows[1] = checkSettle(
                marketId,
                maturityTimestamp,
                2, // accountId,
                vm.addr(2), // user
                110e6, // deposited margin
                takers[0].executedBaseAmount,
                takers[0].executedQuoteAmount,
                takers[0].fee, // fee
                1.1e18 // liquidityindex
            );
            /* cashflow ~=
            (   + 600 * (1.05 - 1) * 2
                - 600 * ((1.03432)^(1/2) - 1)
                - 600 * ((1.034967)^(1/2) - 1)
            ) - 600 * 0.001
             */
            assertEq(takers[0].fee, 120000);
            assertGt(cashflows[1], 0);
            assertAlmostEq(cashflows[1], int256(38790888), absUtil(cashflows[1] / 100)); // 1% diff

            // FT 1
            cashflows[2] = checkSettle(
                marketId,
                maturityTimestamp,
                3, // accountId,
                vm.addr(3), // user
                60e6, // deposited margin
                takers[1].executedBaseAmount,
                takers[1].executedQuoteAmount,
                takers[1].fee, // fee
                1.1e18 // liquidityindex
            );
            /* cashflow ~=
            (   - 100 * (1.05 - 1) * 2
                + 100 * ((1.03464)^(1/2) - 1)
                + 100 * ((1.034967)^(1/2) - 1)
            ) - 100 * 0.001
             */
            assertEq(takers[1].fee, 20000);
            assertLt(cashflows[2], 0);
            assertAlmostEq(cashflows[2], int256(-6649416), absUtil(cashflows[2] / 100)); // 1% diff

            // LP 2
            cashflows[3] = checkSettle(
                marketId,
                maturityTimestamp,
                4, // accountId,
                vm.addr(4), // user
                1000e6, // deposited margin
                -(
                    takers[2].executedBaseAmount / 2 +
                    takers[3].executedBaseAmount / 2
                ),
                -(
                    takers[2].executedQuoteAmount / 2 +
                    takers[3].executedQuoteAmount / 2
                ),
                makers[1].fee, // fee
                1.1e18 // liquidityindex
            );
            /* cashflow ~=
            (   + 250 * 1.05 * ((1.034967)^(1/2) - 1)
                - 250 * 1.05 * (1.1^(1/2)- 1)
            ) + (150) * 1.05 * 0.001
             */
            assertEq(makers[1].fee, 0);
            assertLt(cashflows[3], 0);
            assertAlmostEq(cashflows[3], int256(-7748182), absUtil(cashflows[3] / 100)); // 1% diff

            // VT 2
            cashflows[4] = checkSettle(
                marketId,
                maturityTimestamp,
                5, // accountId,
                vm.addr(5), // user
                110e6, // deposited margin
                takers[2].executedBaseAmount,
                takers[2].executedQuoteAmount,
                takers[2].fee, // fee
                1.1e18 // liquidityindex
            );
            /* cashflow ~=
            (   - 600 * 1.05 * ((1.04)^(1/2) - 1)
                + 600 * 1.05 * (1.05- 1)
            ) - (300) * 1.05 * 0.001
             */
            assertEq(takers[2].fee, 63000);
            assertGt(cashflows[4], 0);
            assertAlmostEq(cashflows[4], int256(18700000), absUtil(cashflows[4] / 100)); // 1% diff

            // FT 2
            cashflows[5] = checkSettle(
                marketId,
                maturityTimestamp,
                6, // accountId,
                vm.addr(6), // user
                10e6, // deposited margin
                takers[3].executedBaseAmount,
                takers[3].executedQuoteAmount,
                takers[3].fee, // fee
                1.1e18 // liquidityIndex
            );
            /* cashflow ~=
            (   + 100 * 1.05 * ((1.04)^(1/2) - 1)
                - 100 * 1.05 * (1.05- 1)
            ) - 50 * 1.05 * 0.001
             */
            assertEq(takers[3].fee, 10500);
            assertLt(cashflows[5], 0);
            assertAlmostEq(cashflows[5], int256(-3223090), absUtil(cashflows[5] / 100)); // 1% diff

            // SOLVENCY
            assertEq(cashflows[0] + cashflows[1] + cashflows[2] + cashflows[3] 
                + cashflows[4] + cashflows[5], 0);
        }

    }

    function test_happy_path_FT_profit() public {
        TakerExecutedAmounts[] memory takers = new TakerExecutedAmounts[](4);
        MakerExecutedAmounts[] memory makers = new MakerExecutedAmounts[](2);

        MarginData[] memory margin = new MarginData[](6);

        // FIRST TRADERS ENTRY
        {
            makers[0] = executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 1,
                user: address(1),
                count: 1,
                merkleIndex: 1, // NEW maker
                margin: 1000e6,
                baseAmount: 10000e6,
                tickLower: -13920, // 4.02261%
                tickUpper: -10260 // 2.80092%
            });

            margin[0] = getMarginData(1);

            // VT
            takers[0] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 2,
                user: address(2),
                count: 1,
                merkleIndex: 2, // NEW taker
                margin: 110e6,
                baseAmount: 600e6
            });

            margin[1] = getMarginData(2);

            // FT
            takers[1] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 3,
                user: address(3),
                count: 1,
                merkleIndex: 3, // NEW taker
                margin: 60e6,
                baseAmount: -100e6
            });

            margin[2] = getMarginData(3);
        }

        // ADVANCE TIME 0.5 years
        vm.warp(block.timestamp + 365 * 12 * 60 * 60);

        // twap 0.034643945147052780
        // uint256 twap = UD60x18.unwrap(contracts.vammProxy.getDatedIRSTwap(marketId, maturityTimestamp, 0, 259200, false, false));
        // console2.log("TWAP after time elapsed", twap);
        // TWAP increased as effect of VT direction over time

        // set index apy -> 1%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.005e18));

        {
            //LP 
            // currentTick = -12426 // console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent)) * li * timeFact
             = 0.013 * 1/2 * 1.005 * (-500e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12426)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 36828111
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
                = -28496888
            */

            // unfilledBaseShort 3862325112
            // unfilledBaseLong 6137674887
            // console2.log(takers[0].executedQuoteAmount); // -621231883
            // console2.log(takers[1].executedQuoteAmount); // 103370686
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12426)))/100 - 0.001)*1/2 + 1) * 1.005 * -6137674887
                = -6261160740
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = (-103370686 + 621231883) - 6261160740 + (38477131 * 2 /0.013) * ((0.034643945147052780 - 0.001)*1/2  + 1)
                = 275837726

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12426) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 1.005 * 3862325112
                = 3956029895
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = (-103370686 + 621231883) + 3956029895 - (-29772868 * 2 /0.013) * ((0.034643945147052780 + 0.001)*1/2  + 1)
                = 9135964820
            */
            MarginData memory marginAfterIndex = getMarginData(1);
            assertEq(marginAfterIndex.liquidationMarginRequirement, 36828111, "Maths LMR LP index growth");
            assertEq(marginAfterIndex.initialMarginRequirement, 55242166, "Maths IMR index growth");
            assertEq(marginAfterIndex.highestUnrealizedLoss, 0, "Maths HUL LP index growth");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * 600e6 / 2 * 1.005
             = 3919500
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -621231883  + 600000000 * 1.005 * ((0.034643945147052780 - 0.001)/2  + 1)
                = -8088233
            */

            marginAfterIndex = getMarginData(2);
            assertEq(marginAfterIndex.liquidationMarginRequirement, 3919500, "Maths LMR VT index growth");
            assertEq(marginAfterIndex.highestUnrealizedLoss, 8088234, "Maths HUL VT index growth");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * -100e6 / 2 * 1.005
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 103370686  - 100000000 * 1.005 * ((0.034643945147052780 + 0.001)/2  + 1)
                = 1079577
            */

            marginAfterIndex = getMarginData(3);
            assertEq(marginAfterIndex.liquidationMarginRequirement, 653250, "Maths LMR FT index growth");
            assertEq(marginAfterIndex.highestUnrealizedLoss, 0, "Maths HUL FT index growth");

            // console2.log("LMR", margin[0].liquidationMarginRequirement);
            // (,,uint256 unfilledQuoteLong,) =
            //     contracts.vammProxy.getAccountUnfilledBaseAndQuote(marketId, maturityTimestamp, 1);

            // console2.log(unfilledQuoteLong);
            
        }

        // NEW TRADERS ENTRY
        {
            makers[1] = executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 4,
                user: address(4),
                count: 1,
                merkleIndex: 4, // NEW maker
                margin: 1000e6,
                baseAmount: 10000e6,
                tickLower: -13920, // 4.02261%
                tickUpper: -10260 // 2.80092%
            });

            margin[3] = getMarginData(4);

            // VT
            takers[2] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 5,
                user: address(5),
                count: 1,
                merkleIndex: 5, // NEW taker
                margin: 110e6,
                baseAmount: 600e6
            });

            margin[4] = getMarginData(5);

            // FT
            takers[3] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 6,
                user: address(6),
                count: 1,
                merkleIndex: 6, // NEW taker
                margin: 10e6,
                baseAmount: -100e6
            });

            margin[5] = getMarginData(6);
        }

        // NEW positions check
        uint256 twap = UD60x18.unwrap(contracts.vammProxy.getDatedIRSTwap(marketId, maturityTimestamp, 0, 259200, false, false));
        console2.log("TWAP after second trades", twap); // 34643945147052780
        {
            //LP 
            // currentTick = -12519
             console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent)) * li * timeFact
             = 0.013 * 1/2 * 1.005 * (-250e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12519)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 40 087 423
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
             = 0.013 * 1/2 * 1.005 * (-250e6 - 10000e6 * (sqrt(1.0001^-12519) - sqrt(1.0001^-13920 )) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
                = -25237576
            */

            // unfilledBaseShort 4112423206
            // unfilledBaseLong 5887576793
            // console2.log(takers[2].executedQuoteAmount); // -613804836
            // console2.log("takers[3].executedQuoteAmount",takers[3].executedQuoteAmount); // 102208499
            // filledQuote LP = 267251818
            
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12519)))/100 - 0.001)*1/2 + 1) * 1.005 * -5887576793
                = -6006459499
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = (-102208499 + 613804836)/2 - 6006459499 + (41882382 * 2 /0.013) * ((0.034643945147052780 - 0.001)*1/2  + 1)
                = 801 173 482

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12519) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 1.005 * 4112423206
                = 4212555214
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = (-102208499 + 613804836)/2 + 4212555214 - (-26367617 * 2 /0.013) * ((0.034643945147052780+ 0.001)*1/2  + 1)
                = 8 597 205 682
            */
            MarginData memory margin2 = getMarginData(4);
            assertEq(margin2.liquidationMarginRequirement, 40087422, "Maths LMR LP 2");
            assertEq(margin2.highestUnrealizedLoss, 0, "Maths HUL LP 2");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * 600e6 / 2 * 1.005 = 3919500
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -613804836  + 600000000 * 1.005 * ((0.034643945147052780 - 0.001)/2  + 1)
                = -661186
            */

            margin2 = getMarginData(5);
            assertEq(margin2.liquidationMarginRequirement, 3919500, "Maths LMR VT 2");
            assertEq(margin2.highestUnrealizedLoss, 661187, "Maths HUL VT 2");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * -100e6 / 2 * 1.005
             = -653250
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 102208499  - 100000000 * 1.005 * ((0.034643945147052780 + 0.001)/2  + 1)
                = -82609
            */

            margin2 = getMarginData(6);
            assertEq(margin2.liquidationMarginRequirement, 653250, "Maths LMR FT 2");
            assertEq(margin2.highestUnrealizedLoss, 82609, "Maths HUL FT 2");
            
        }

        {
            //LP 
            // currentTick = -12519 // console2.log(contracts.vammProxy.getVammTick(marketId, maturityTimestamp));

            /* LMR Long= riskParam * (filledB + unfilledBLong) * li * timeFact
             = riskParam * (filledB + liq * (sqrtHigh - sqrtCurrent))
             = 0.013 * 1/2 * 1.005 * (-750e6 + 10000e6 * (sqrt(1.0001^-10260) - sqrt(1.0001^-12519)) /  (sqrt(1.0001^-10260) - sqrt(1.0001^-13920 )))
             LMR Long = 36821172
             LMR Short = riskParam * li * t * (filledB - liq * (sqrtCurrent - sqrtLow))
                = -18705076
            */

            // unfilledBaseShort 3613387217
            // unfilledBaseLong 6386612782
            // console2.log(takers[0].executedQuoteAmount); // -621231883
            // console2.log(takers[1].executedQuoteAmount); // 103370686
            /* 
            unfilledQuoteLong = ((1/sqrtCurr/sqrtHigh/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-10260) * sqrt(1.0001^-12519)))/100 - 0.001)*1/2 + 1) * 1.005 * -6386612782
                = -6515572086
            HUL Long = filledQuote + unfilledQuoteLong + (filledB + unfilledBLong) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteLong
                    + (filledB + liq * (sqrtHigh - sqrtCurrent)) * (twap_adj + 1) 
                = 785113015 - 6515572086 + 36821172 * 2 /0.013 * ((0.034643945147052780 - 0.001)*1/2  + 1)
                = 29629659

            unfilledQuoteShort = ((1/sqrtCurr/sqrtLow/100 + spread)*timefact + 1) * li * -unfilledBaseLong
                = (((1/(sqrt(1.0001^-12519) * sqrt(1.0001^-13920)))/100 + 0.001)*1/2 + 1) * 1.005 * 3613387217
                = 3701368366
            HUL Short = filledQuote + unfilledQuoteShort + (filledB - unfilledBShort) * li * (twap_adj * t + 1)
                = (-takers[0].execQuote - takers[1].execQuote) + unfilledQuoteShort
                    + (filledB + liq * (sqrtCurrent - sqrtLow)) * (twap_adj + 1) 
                = 785113015 + 3701368366 - 18705076 * 2 /0.013 * ((0.034643945147052780 + 0.001)*1/2  + 1)
                = 1557491019
                
            */
            MarginData memory margin2 = getMarginData(1);
            assertEq(margin2.liquidationMarginRequirement, 36821172, "Maths LMR LP 2");
            assertEq(margin2.highestUnrealizedLoss, 0, "Maths HUL LP 2");


            // VT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * 600e6 / 2 * 1.005
            console2.log(takers[0].executedQuoteAmount); // -621231883
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = -621231883  + 600000000 * 1.005 * ((0.034643945147052780 - 0.001)/2  + 1)
                = -8088233
            */

            margin2 = getMarginData(2);
            assertEq(margin2.liquidationMarginRequirement, 3919500, "Maths LMR VT index growth");
            assertEq(margin2.initialMarginRequirement, 5879250, "Maths IMR VT index growth");
            assertEq(margin2.highestUnrealizedLoss, 8088234, "Maths HUL VT index growth");

            // FT
            /* LMR = riskParam * (filledB) * li * timeFact
             = 0.013 * -100e6 / 2 * 1.005
            console2.log(takers[1].executedQuoteAmount); // 103370686
            HUL = filledQuote + (filledB) * li * (twap_adj * t + 1)
                = 103370686  - 100000000 * 1.005 * ((0.034643945147052780 + 0.001)/2  + 1)
                = 1079577
            */

            margin2 = getMarginData(3);
            assertEq(margin2.liquidationMarginRequirement, 653250, "Maths LMR FT index growth");
            assertEq(margin2.initialMarginRequirement, 979875, "Maths IMR FT index growth");
            assertEq(margin2.highestUnrealizedLoss, 0, "Maths HUL FT index growth");
            
        }

        vm.warp(block.timestamp + 365 * 12 * 60 * 60 + 1);
        // set index apy -> 1%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.010025e18));

        // SETTLE
        {
            int256[] memory cashflows = new int256[](6);

            // LP 1
            cashflows[0] = checkSettle(
                marketId,
                maturityTimestamp,
                1, // accountId,
                vm.addr(1), // user
                1000e6 - 1, // deposited margin
                -(
                    takers[0].executedBaseAmount +
                    takers[1].executedBaseAmount +
                    takers[2].executedBaseAmount / 2 +
                    takers[3].executedBaseAmount / 2
                ),
                -(
                    takers[0].executedQuoteAmount +
                    takers[1].executedQuoteAmount +
                    takers[2].executedQuoteAmount / 2 +
                    takers[3].executedQuoteAmount / 2
                ),
                makers[0].fee, // fee
                1.010025e18 // liquidityindex
            );
            /* cashflow ~=
            ( + 500 * ((1.03464)^(1/2) - 1)
                + 750 * ((1.034967)^(1/2) - 1)
                - 500 * (1.005 - 1) 
                - 750 * (1.005 - 1)
            ) + (600 + 300) * 0.001
             */
            assertEq(makers[0].fee, 0);
            assertGt(cashflows[0], 0);
            assertAlmostEq(cashflows[0], int256(16236234), absUtil(cashflows[0] / 100)); // 1% diff

            // VT 1
            cashflows[1] = checkSettle(
                marketId,
                maturityTimestamp,
                2, // accountId,
                vm.addr(2), // user
                110e6, // deposited margin
                takers[0].executedBaseAmount,
                takers[0].executedQuoteAmount,
                takers[0].fee, // fee
                1.010025e18 // liquidityindex
            );
            /* cashflow ~=
            (   + 600 * (1.005 - 1) * 2
                - 600 * ((1.03432)^(1/2) - 1)
                - 600 * ((1.034967)^(1/2) - 1)
            ) - 600 * 0.001
             */
            assertEq(takers[0].fee, 120000);
            assertLt(cashflows[1], 0);
            assertAlmostEq(cashflows[1], int256(-15209111), absUtil(cashflows[1] / 100)); // 1% diff

            // FT 1
            cashflows[2] = checkSettle(
                marketId,
                maturityTimestamp,
                3, // accountId,
                vm.addr(3), // user
                60e6, // deposited margin
                takers[1].executedBaseAmount,
                takers[1].executedQuoteAmount,
                takers[1].fee, // fee
                1.010025e18 // liquidityindex
            );
            /* cashflow ~=
            (   - 100 * (1.005 - 1) * 2
                + 100 * ((1.03464)^(1/2) - 1)
                + 100 * ((1.034967)^(1/2) - 1)
            ) - 100 * 0.001
             */
            assertEq(takers[1].fee, 20000);
            assertGt(cashflows[2], 0);
            assertAlmostEq(cashflows[2], int256(2350583), absUtil(cashflows[2] / 100)); // 1% diff

            // LP 2
            cashflows[3] = checkSettle(
                marketId,
                maturityTimestamp,
                4, // accountId,
                vm.addr(4), // user
                1000e6 - 1, // deposited margin
                -(
                    takers[2].executedBaseAmount / 2 +
                    takers[3].executedBaseAmount / 2
                ),
                -(
                    takers[2].executedQuoteAmount / 2 +
                    takers[3].executedQuoteAmount / 2
                ),
                makers[1].fee, // fee
                1.010025e18 // liquidityindex
            );
            /* cashflow ~=
            (   + 250 * 1.005 * ((1.035)^(1/2) - 1)
                - 250 * 1.005 * (1.010025^(1/2)- 1)
            ) + (150) * 1.005 * 0.001
             */
            assertEq(makers[1].fee, 0);
            assertGt(cashflows[3], 0);
            assertAlmostEq(cashflows[3], int256(3315295), absUtil(cashflows[3] / 100)); // 1% diff

            // VT 2
            cashflows[4] = checkSettle(
                marketId,
                maturityTimestamp,
                5, // accountId,
                vm.addr(5), // user
                110e6, // deposited margin
                takers[2].executedBaseAmount,
                takers[2].executedQuoteAmount,
                takers[2].fee, // fee
                1.010025e18 // liquidityindex
            );
            /* cashflow ~=
            (   - 600 * 1.005 * ((1.035)^(1/2) - 1)
                + 600 * 1.005 * (1.005- 1)
            ) - (300) * 1.005 * 0.001
             */
            assertEq(takers[2].fee, 60300);
            assertLt(cashflows[4], 0);
            assertAlmostEq(cashflows[4], int256(-7748246), absUtil(cashflows[4] / 100)); // 1% diff

            // FT 2
            cashflows[5] = checkSettle(
                marketId,
                maturityTimestamp,
                6, // accountId,
                vm.addr(6), // user
                10e6, // deposited margin
                takers[3].executedBaseAmount,
                takers[3].executedQuoteAmount,
                takers[3].fee, // fee
                1.010025e18 // liquidityIndex
            );
            /* cashflow ~=
            (   + 100 * 1.005 * ((1.0353)^(1/2) - 1)
                - 100 * 1.005 * (1.005- 1)
            ) - 50 * 1.005 * 0.001
             */
            assertEq(takers[3].fee, 10050);
            assertGt(cashflows[5], 0);
            assertAlmostEq(cashflows[5], int256(1205999), absUtil(cashflows[5] / 100)); // 1% diff

            // SOLVENCY
            assertAlmostEq(cashflows[0] + cashflows[1] + cashflows[2] + cashflows[3] 
                + cashflows[4] + cashflows[5], int256(0), uint256(1)); // +-1
        }

    }

}
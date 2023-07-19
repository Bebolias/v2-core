pragma solidity >=0.8.19;

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

import "forge-std/console2.sol";

contract Scenario1 is ScenarioHelper {
    uint32 maturityTimestamp = 1719788400; // 1 year pool
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

    function test_happy_path() public {
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

            margin[1] = getMarginData(1);

            // FT
            takers[1] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 3,
                user: address(3),
                count: 1,
                merkleIndex: 3, // NEW taker
                margin: 230e6,
                baseAmount: -100e6
            });

            margin[2] = getMarginData(1);
        }

        // CHECK EFFECTS OF OF TRADING
        margin[0] = compareCurrentMarginData(1, margin[0], true); // hul grows due to twap
        margin[1] = compareCurrentMarginData(2, margin[1], false); // hul reduces due to twap
        // margin[2] = compareCurrentMarginData(3, margin[2], false);

        // VERIFY MARGIN DATA
        {
            //LP 
            // lmr = riskParam * (filledB + unfilledBLong) * li * timeFact
            // = riskParam * (filledB + unfilledBLong)
            // = rP * (500 + )
        }

        // print twap
        uint256 twap = UD60x18.unwrap(contracts.vammProxy.getDatedIRSTwap(marketId, maturityTimestamp, 0, 259200, false, false));
        console2.log("TWAP after swaps", twap);

        // ADVANCE TIME 0.5 years
        vm.warp(block.timestamp + 356 * 12 * 60 * 60);
        // set index apy -> 10%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.005e18));

        // CHECK EFFECTS OF TIME ELAPSED
        margin[0] = compareCurrentMarginData(1, margin[0], true); // hul grows due to twap
        margin[1] = compareCurrentMarginData(2, margin[1], false); // hul reduces due to twap
        // margin[2] = compareCurrentMarginData(3, margin[2], false);

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

            // FT
            takers[2] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 5,
                user: address(5),
                count: 1,
                merkleIndex: 5, // NEW taker
                margin: 110e6,
                baseAmount: -600e6
            });

            margin[4] = getMarginData(5);

            // VT
            takers[3] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 6,
                user: address(6),
                count: 1,
                merkleIndex: 6, // NEW taker
                margin: 10e6,
                baseAmount: 100e6
            });

            margin[5] = getMarginData(6);
        }

        // CHECK EFFECTS OF OF TRADING
        margin[0] = compareCurrentMarginData(1, margin[0], true); // hul grows due to twap
        margin[1] = compareCurrentMarginData(2, margin[1], false); // hul reduces due to twap
        // margin[2] = compareCurrentMarginData(3, margin[2], false);

    }

}
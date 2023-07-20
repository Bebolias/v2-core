pragma solidity >=0.8.19;

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

contract ScenarioVariableRateUp is ScenarioHelper {
    uint32 public maturityTimestamp = 1704110400; // 1 year pool
    uint128 public marketId = 1;

    function setUp() public {
        address[] memory accessPassOwners = new address[](7);
        accessPassOwners[0] = owner; // note: do not change owner's index 0
        accessPassOwners[1] = address(1);
        accessPassOwners[2] = address(2);
        accessPassOwners[3] = address(3);
        accessPassOwners[4] = address(4);
        accessPassOwners[5] = address(5);
        accessPassOwners[6] = address(6);
        setUpAccessPassNft(accessPassOwners);
        redeemAccessPass(owner, 1, 0);

        acceptOwnerships();
    
        address[] memory pausers = new address[](0);
        enableFeatureFlags({
            pausers: pausers
        });
    
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
    
        vm.warp(1672574400); 

        uint32[] memory times = new uint32[](2);
        int24[] memory observedTicks = new int24[](2);

        times[0] = uint32(block.timestamp - 86400*4);
        observedTicks[0] = -13860; // 4%
    
        times[1] = uint32(block.timestamp - 86400*3);
        observedTicks[1] = -13860; // 4%
    
        deployPool({
            immutableConfig: VammConfiguration.Immutable({
                maturityTimestamp: maturityTimestamp,
                _maxLiquidityPerTick: type(uint128).max,
                _tickSpacing: 60,
                marketId: marketId
            }),
            mutableConfig: VammConfiguration.Mutable({
                priceImpactPhi: ud60x18(0),
                priceImpactBeta: ud60x18(0),
                spread: ud60x18(0.001e18),
                rateOracle: IRateOracle(address(contracts.aaveV3RateOracle)),
                minTick: -69060,
                maxTick: 69060
            }),
            initTick: -13860, // 4%
            observationCardinalityNext: 20,
            makerPositionsPerAccountLimit: 1,
            times: times,
            observedTicks: observedTicks
        });

        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18));
    }

    function test_variable_rate_up() public {
        TakerExecutedAmounts[] memory takers = new TakerExecutedAmounts[](4);
        MakerExecutedAmounts[] memory makers = new MakerExecutedAmounts[](2);

        {
            makers[0] = executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 1,
                user: address(1),
                count: 1,
                merkleIndex: 1,
                margin: 1000e6,
                baseAmount: 10000e6,
                // tickLower: -17940, // 6%
                tickLower: -13860, // 4%
                tickUpper: -6960 // 2%
            });

            takers[0] = executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 2,
                user: address(2),
                count: 1,
                merkleIndex: 2,
                margin: 1000e6,
                baseAmount: -10000e6
            });

            assertAlmostEq(takers[0].executedBaseAmount, -10000e6, 500);
        }

        UD60x18 apy = ud60x18(0.4e18); // 40% APY

        UD60x18 elapsedPeriod = ud60x18(91 * 24 * 60 * 60 * 1e18);
        UD60x18 secondsInYear = ud60x18(365 * 24 * 60 * 60 * 1e18);
    
        vm.warp(1672574400 + elapsedPeriod.unwrap() / 1e18);
        
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
        .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18).add(apy.mul(elapsedPeriod.div(secondsInYear))));

        {
            MarginData memory margin = getMarginData(2);

            assertEq(margin.liquidatable, true);
            assertGt(margin.liquidationMarginRequirement, 0);
            assertGt(margin.highestUnrealizedLoss, 0);
        }

        liquidateAccount(address(1), 1, 2);

        {
            MarginData memory margin = getMarginData(2);

            assertEq(margin.liquidatable, false);
            assertEq(margin.liquidationMarginRequirement, 0);
            assertGt(margin.highestUnrealizedLoss, 0);
        }

        vm.warp(1704110401);
        
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
        .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18).add(apy));

        settleAccount(address(2), 2, marketId, maturityTimestamp);

        uint256 balance = getCollateralBalance(2);
        assertAlmostEq(balance, 29.248865e6, 500);
    }
}
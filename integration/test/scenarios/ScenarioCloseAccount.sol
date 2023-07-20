pragma solidity >=0.8.19;

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

contract ScenarioCloseAccount is ScenarioHelper {
    uint32 public maturityTimestamp = 1704110400; // 1 year pool
    uint128 public marketId = 1;

    function setUp() public {
        address[] memory accessPassOwners = new address[](7);
        accessPassOwners[0] = owner; // note: do not change owner's index 0
        accessPassOwners[1] = address(1); 
        accessPassOwners[2] = address(2); 
        accessPassOwners[3] = address(3); 
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

    function test_close_account_and_upnl() public {
        {
            // LP: deploys liquidity between 2-6%
            executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 1,
                user: address(1),
                count: 1,
                merkleIndex: 1,
                margin: 1000e6, // 1k
                baseAmount: 10000e6, // 10k
                tickLower: -17940, // 6%
                tickUpper: -6960 // 2%
            });

            // A: brings fixed rate down to 3%
            executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 2,
                user: address(2),
                count: 1,
                merkleIndex: 2,
                margin: 1000e6,
                baseAmount: -2596e6
            });

            // B: trades 1 notional VT at 3%
            executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 3,
                user: address(3),
                count: 1,
                merkleIndex: 3,
                margin: 1e6,
                baseAmount: 1e6
            });

            // A: brings fixed rate up to 5%
            editExecuteTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamp,
                accountId: 2,
                user: address(2),
                margin: 0,
                baseAmount: 4357e6
            });

            // B: closes account
            closeAccount(address(3), 3);

            // Check margin requirement of B post unwind
            MarginData memory margin = getMarginData(3);

            assertEq(margin.liquidationMarginRequirement, 0);
            assertEq(margin.highestUnrealizedLoss, 0);

            // Advance to maturity
            vm.warp(1704110401);

            // Set liquidity index to simulate 3% APY
            MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.03e18));

            // B: settles closed account
            settleAccount(address(3), 3, marketId, maturityTimestamp);

            // Check balance
            {
                uint256 balance = getCollateralBalance(3);
                assertAlmostEq(balance, 1e6 + 0.017943e6, 500);
            }
        }
    }
}
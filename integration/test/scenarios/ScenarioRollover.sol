pragma solidity >=0.8.19;

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

contract ScenarioRollover is ScenarioHelper {
    uint32[] public maturityTimestamps = [1704110400, 1735646400]; // 1 year pools
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
    
        for (uint256 i = 0 ; i < 2; i++) {
            deployPool({
                immutableConfig: VammConfiguration.Immutable({
                    maturityTimestamp: maturityTimestamps[i],
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
        }

        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18));
    }

    function test_rollover() public {
        // Activity on the first pool
        {
            executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[0],
                accountId: 6,
                user: address(6),
                count: 1,
                merkleIndex: 6,
                margin: 1000e6,
                baseAmount: 10000e6,
                tickLower: -13860, // 4%
                tickUpper: -10980 // 3%
            });

            executeMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[0],
                accountId: 5,
                user: address(5),
                count: 1,
                merkleIndex: 5,
                margin: 1000e6,
                baseAmount: 10000e6,
                tickLower: -10980, // 3%
                tickUpper: -6960 // 2%
            });

            executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[0],
                accountId: 1,
                user: address(1),
                count: 1,
                merkleIndex: 1,
                margin: 1000e6,
                baseAmount: -20000e6
            });

            executeTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[0],
                accountId: 2,
                user: address(2),
                count: 1,
                merkleIndex: 2,
                margin: 1000e6,
                baseAmount: 5000e6
            });
        }

        // Advance to reach maturity for 1st pool
        vm.warp(1704110401);

        // Set liquidity index to simulate APY of 1%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
        .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.01e18));
    
        // Settle all accounts in this pool and check their balances
        settleAccount(address(1), 1, marketId, maturityTimestamps[0]);
        settleAccount(address(2), 2, marketId, maturityTimestamps[0]);
        settleAccount(address(5), 5, marketId, maturityTimestamps[0]);
        settleAccount(address(6), 6, marketId, maturityTimestamps[0]);

        {
            uint256 balance = getCollateralBalance(1);
            assertAlmostEq(balance, 1000e6 + 371.444198e6, 500);
        }

        {
            uint256 balance = getCollateralBalance(2);
            assertAlmostEq(balance, 1000e6 + -65.326267e6, 500);
        }

        {
            uint256 balance = getCollateralBalance(5);
            assertAlmostEq(balance, 1000e6 + -69.886270e6, 500);
        }

        {
            uint256 balance = getCollateralBalance(6);
            assertAlmostEq(balance, 1000e6 + -236.231661e6, 500);
        }

        // Activity on the 2nd pool
        {
            editExecuteMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[1],
                accountId: 6,
                user: address(6),
                margin: 0,
                baseAmount: 10000e6,
                tickLower: -13860, // 4%
                tickUpper: -10980 // 3%
            });

            editExecuteMakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[1],
                accountId: 5,
                user: address(5),
                margin: 0,
                baseAmount: 10000e6,
                tickLower: -10980, // 3%
                tickUpper: -6960 // 2%
            });

            editExecuteTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[1],
                accountId: 1,
                user: address(1),
                margin: 0,
                baseAmount: -20000e6
            });

            editExecuteTakerOrder({
                _marketId: marketId,
                _maturityTimestamp: maturityTimestamps[1],
                accountId: 2,
                user: address(2),
                margin: 0,
                baseAmount: 5000e6
            });
        }

        vm.warp(1735646401);

        // Set liquidity index to simulate APY of 1%
        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
        .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1.0201e18));
    
        // Settle all accounts in this pool and check their balances
        settleAccount(address(1), 1, marketId, maturityTimestamps[1]);
        settleAccount(address(2), 2, marketId, maturityTimestamps[1]);
        settleAccount(address(5), 5, marketId, maturityTimestamps[1]);
        settleAccount(address(6), 6, marketId, maturityTimestamps[1]);

        {
            uint256 balance = getCollateralBalance(1);
            assertAlmostEq(balance, 1000e6 + 746.602820e6, 500);
        }

        {
            uint256 balance = getCollateralBalance(2);
            assertAlmostEq(balance, 1000e6 + -131.305793e6, 500);
        }

        {
            uint256 balance = getCollateralBalance(5);
            assertAlmostEq(balance, 1000e6 + -140.471400e6, 500);
        }

        {
            uint256 balance = getCollateralBalance(6);
            assertAlmostEq(balance, 1000e6 + -474.825628e6, 500);
        }
    }
}
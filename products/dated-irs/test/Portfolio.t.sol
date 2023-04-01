pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "../src/storage/Portfolio.sol";
import "../src/storage/PoolConfiguration.sol";
import "../src/storage/RateOracleReader.sol";
import "./mocks/MockRateOracle.sol";
import "./mocks/MockPool.sol";
import "@voltz-protocol/core/src/storage/Account.sol";
import { UD60x18, ud, unwrap as uUnwrap} from "@prb/math/UD60x18.sol";
import { SD59x18, unwrap as sUnwrap } from "@prb/math/SD59x18.sol";

contract ExposePortfolio {
    using { uUnwrap } for UD60x18;
    using Portfolio for Portfolio.Data;
    using SetUtil for SetUtil.UintSet;
    using RateOracleReader for RateOracleReader.Data;

    // Exposed functions
    function load(uint128 id) external pure returns (bytes32 s) {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        assembly {
            s := portfolio.slot
        }
    }

    function create(uint128 id) external returns (bytes32 s) {
        Portfolio.Data storage portfolio = Portfolio.create(id);
        assembly {
            s := portfolio.slot
        }
    }

    function getAccountAnnualizedExposures(uint128 id, address poolAddress) external returns (Account.Exposure[] memory) {
        return Portfolio.load(id).getAccountAnnualizedExposures(poolAddress);
    }

    function getAccountUnrealizedPnL(uint128 id, address poolAddress) external returns (SD59x18) {
        return Portfolio.load(id).getAccountUnrealizedPnL(poolAddress);
    }

    function annualizedExposureFactor(uint128 marketId, uint32 maturityTimestamp) external returns (UD60x18) {
        return Portfolio.annualizedExposureFactor(marketId, maturityTimestamp);
    }

    function activateMarketMaturity(uint128 id, uint128 marketId, uint32 maturityTimestamp) external {
        Portfolio.load(id).activateMarketMaturity(marketId, maturityTimestamp);
    }

    function deactivateMarketMaturity(uint128 id, uint128 marketId, uint32 maturityTimestamp) external {
        Portfolio.load(id).deactivateMarketMaturity(marketId, maturityTimestamp);
    }

    function closeAccount(uint128 id, address poolAddress) external {
        Portfolio.load(id).closeAccount(poolAddress);
    }

    function updatePosition(uint128 id, uint128 marketId, uint32 maturityTimestamp, SD59x18 baseDelta, SD59x18 quoteDelta) external {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.updatePosition(marketId, maturityTimestamp, baseDelta, quoteDelta);
    }

    function settle(uint128 id, uint128 marketId, uint32 maturityTimestamp, address poolAddress) external returns (SD59x18 settlementCashflow) {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.settle(marketId, maturityTimestamp, poolAddress);
    }

    function updateCache(uint128 marketId, uint32 maturityTimestamp) external {
        RateOracleReader.load(marketId).updateCache(maturityTimestamp);
    }

    function createRateOracle(uint128 marketId, address rateOracleAddress) external {
        RateOracleReader.create(marketId, rateOracleAddress);
    }

    // EXTRA GETTERS

    function getPositionData(
        uint128 id,
        uint128 marketId,
        uint32 maturityTimestamp
    )
        external
        returns (Position.Data memory position)
    {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        position = portfolio.positions[marketId][maturityTimestamp];
    }

    function isActiveMarketAndMaturity(uint128 id, uint128 marketId, uint32 maturityTimestamp) external returns (bool) {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.activeMarketsAndMaturities.contains((marketId << 32) | maturityTimestamp);
    }
}

contract PortfolioTest is Test {
    using { sUnwrap } for SD59x18;
    using { uUnwrap } for UD60x18;
    using Portfolio for Portfolio.Data;
    using RateOracleReader for RateOracleReader.Data;

    ExposePortfolio portfolio;

    MockRateOracle mockRateOracle;
    MockPool mockPool;
    uint32 public maturityTimestamp;
    uint32 currentTimestamp;

    uint32 internal constant ONE_YEAR = 3139000;
    uint128 internal constant marketId = 100;
    uint128 internal constant accountId = 200;
    bytes32 internal constant portfolioSlot = keccak256(abi.encode("xyz.voltz.Portfolio", accountId));

    function setUp() public virtual {
        currentTimestamp = Time.blockTimestampTruncated();

        mockPool = new MockPool();
        mockRateOracle = new MockRateOracle();

        PoolConfiguration.set(PoolConfiguration.Data({ poolAddress: address(mockPool) }));
        maturityTimestamp = currentTimestamp + ONE_YEAR;

        portfolio = new ExposePortfolio();
        portfolio.create(accountId);
        portfolio.createRateOracle(marketId, address(mockRateOracle));
    }

    function test_CreateAtCorrectSlot() public {
        bytes32 slot = portfolio.load(accountId);
        assertEq(slot, portfolioSlot);
    }

    function test_GetAccountUnrealizedPnLNoActivPositions() public {
        SD59x18 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL.sUnwrap(), 0);
    }

    function test_GetAccountUnrealizedPnLWithTraderPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + 31540000;
        uint32 maturityTimestamp2 = currentTimestamp + 31540000 / 2;
        uint256 liqudityIndex = 1e27;
        UD60x18 gwap1 = ud(0.3e18); // 30% -> 1.3 * base
        UD60x18 gwap2 = ud(0.05e18); // 5% ->1 + (0.05 * 1/2) * base

        portfolio.updatePosition(accountId, marketId, maturityTimestamp1, sd(1000 * 1e18), sd(500 * 1e18));
        portfolio.updatePosition(accountId, marketId, maturityTimestamp2, sd(100 * 1e18), sd(20 * 1e18));
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp1, gwap1);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp2, gwap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        // set gwap
        SD59x18 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL.sUnwrap(), 19225 * 1e17);
    }

    function test_GetAccountUnrealizedPnLWithLpPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + 31540000;
        uint32 maturityTimestamp2 = currentTimestamp + 31540000 / 2;
        uint256 liqudityIndex = 1e27;
        UD60x18 gwap1 = ud(0.3e18);
        UD60x18 gwap2 = ud(0.05e18);

        portfolio.activateMarketMaturity(accountId, marketId, maturityTimestamp1);
        portfolio.activateMarketMaturity(accountId, marketId, maturityTimestamp2);

        // same for both positions
        mockPool.setBalances(
            sd(1500 * 1e18), // _baseBalancePool
            sd(-210 * 1e18), // _quoteBalancePool
            ZERO, // _unfilledBaseLong
            ZERO // _unfilledBaseShort
        );

        mockPool.setDatedIRSGwap(marketId, maturityTimestamp1, gwap1);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp2, gwap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        // set gwap
        SD59x18 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL.sUnwrap(), 30675 * 1e17);
    }

    function test_GetAccountUnrealizedPnLWithTraderAndLpPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + 31540000;
        uint32 maturityTimestamp2 = currentTimestamp + 31540000 / 2;
        uint256 liqudityIndex = 1e27;
        UD60x18 gwap1 = ud(0.3e18);
        UD60x18 gwap2 = ud(0.05e18);

        // trader position
        portfolio.updatePosition(accountId, marketId, maturityTimestamp1, sd(1000 * 1e18), sd(500 * 1e18));

        // LP position
        portfolio.activateMarketMaturity(accountId, marketId, maturityTimestamp2);
        // same for both positions
        mockPool.setBalances(
            sd(1500 * 1e18), // _baseBalancePool
            sd(-210 * 1e18), // _quoteBalancePool
            ZERO, // _unfilledBaseLong
            ZERO // _unfilledBaseShort
        );

        mockPool.setDatedIRSGwap(marketId, maturityTimestamp1, gwap1);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp2, gwap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        // set gwap
        SD59x18 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        // 1300 + 1950 + 500 - 210 = 3540
        // 0 + 1537.5 + 0 - 210 = 1327.5
        assertEq(unrealizedPnL.sUnwrap(), 48675 * 1e17);
    }

    function test_CreateNewPosition() public {
        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.updatePosition(accountId, marketId, maturityTimestamp, sd(10), sd(20));

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance.sUnwrap(), 10);
        assertEq(position.quoteBalance.sUnwrap(), 20);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp));
    }

    function test_UpdatePosition() public {
        // use previous setup
        test_CreateNewPosition();

        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.updatePosition(accountId, marketId, maturityTimestamp, sd(10), sd(20));

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance.sUnwrap(), 20);
        assertEq(position.quoteBalance.sUnwrap(), 40);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp));
    }

    function test_CloseAccount() public {
        test_CreateNewPosition();
        uint32 maturityTimestamp = currentTimestamp + 2;
        vm.expectCall(
            address(mockPool), 0, abi.encodeWithSelector(mockPool.executeDatedTakerOrder.selector, marketId, maturityTimestamp, -10)
        );
        portfolio.closeAccount(accountId, address(mockPool));
    }

    function test_Settle() public {
        test_CreateNewPosition();
        uint32 maturityTimestamp = currentTimestamp + 2;

        vm.warp(maturityTimestamp + 1);

        mockRateOracle.setLastUpdatedIndex(1e27);
        portfolio.updateCache(marketId, maturityTimestamp);

        SD59x18 settlementCashflow = portfolio.settle(accountId, marketId, maturityTimestamp, address(mockPool));
        assertEq(settlementCashflow.sUnwrap(), 30);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);
        assertEq(position.baseBalance.sUnwrap(), 0);
        assertEq(position.quoteBalance.sUnwrap(), 0);
    }

    function test_ActivatePool() public {
        portfolio.activateMarketMaturity(accountId, marketId, 21988);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988));
    }

    function test_DeactivateActivePool() public {
        portfolio.activateMarketMaturity(accountId, marketId, 21988);
        portfolio.deactivateMarketMaturity(accountId, marketId, 21988);
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988));
    }

    function test_DeactivateInactivePool() public {
        portfolio.deactivateMarketMaturity(accountId, marketId, 21988);
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988));
    }

    function test_SettleExistingPosition() public {
        test_CreateNewPosition();

        uint32 maturityTimestamp = currentTimestamp + 2;
        mockRateOracle.setLastUpdatedIndex(1e27);

        vm.warp(maturityTimestamp + 1);
        portfolio.updateCache(marketId, maturityTimestamp);

        SD59x18 settlementCashflow = portfolio.settle(accountId, marketId, maturityTimestamp, address(mockPool));

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance.sUnwrap(), 0);
        assertEq(position.quoteBalance.sUnwrap(), 0);
        assertEq(settlementCashflow.sUnwrap() , 30);
    }

    function test_AnnualizedExposureFactorBeforeMaturity() public {
        uint32 maturityTimestamp = currentTimestamp + 31540000;
        mockRateOracle.setLastUpdatedIndex(1e27);

        UD60x18 factor = portfolio.annualizedExposureFactor(marketId, maturityTimestamp);

        assertEq(factor.uUnwrap(), 1e18);
    }

    function test_AnnualizedExposureFactorAfterMaturity() public {
        uint32 maturityTimestamp = currentTimestamp - 1;
        mockRateOracle.setLastUpdatedIndex(1e27);
        portfolio.updateCache(marketId, maturityTimestamp);

        UD60x18 factor = portfolio.annualizedExposureFactor(marketId, maturityTimestamp);

        assertEq(factor.uUnwrap(), 0);
    }

    function test_AccountAnnualizedExposureTaker() public {
        uint32 maturityTimestamp = currentTimestamp + 31540000;

        portfolio.updatePosition(accountId, marketId, maturityTimestamp, sd(10 * 1e6), sd(20 * 1e6));

        mockRateOracle.setLastUpdatedIndex(1e27);

        Account.Exposure[] memory exposures = portfolio.getAccountAnnualizedExposures(accountId, address(mockPool));

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, marketId);
        assertEq(exposures[0].filled.sUnwrap(), 1e7);
        assertEq(exposures[0].unfilledLong.sUnwrap(), 0);
        assertEq(exposures[0].unfilledShort.sUnwrap(), 0);
    }

    function test_AccountAnnualizedWithPosition() public {
        uint32 maturityTimestamp = currentTimestamp + 31540000;

        portfolio.updatePosition(accountId, marketId, maturityTimestamp, sd(10), sd(20));
        mockPool.setBalances(sd(15), sd(21), sd(2), sd(-3));

        mockRateOracle.setLastUpdatedIndex(1e27);

        Account.Exposure[] memory exposures = portfolio.getAccountAnnualizedExposures(accountId, address(mockPool));

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, marketId);
        assertEq(exposures[0].filled.sUnwrap(), 25);
        assertEq(exposures[0].unfilledLong.sUnwrap(), 2);
        assertEq(exposures[0].unfilledShort.sUnwrap(), -3);
    }
}

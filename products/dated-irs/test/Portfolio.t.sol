pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../src/storage/Portfolio.sol";
import "../src/storage/PoolConfiguration.sol";
import "../src/storage/RateOracleReader.sol";
import "./mocks/MockRateOracle.sol";
import "./mocks/MockPool.sol";
import "@voltz-protocol/core/src/storage/Account.sol";
import { UD60x18, ud, unwrap } from "../../lib/prb-math/src/UD60x18.sol";

contract ExposePortfolio {
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

    function getAccountUnrealizedPnL(uint128 id, address poolAddress) external returns (int256) {
        return Portfolio.load(id).getAccountUnrealizedPnL(poolAddress);
    }

    function annualizedExposureFactor(uint128 marketId, uint32 maturityTimestamp) external returns (int256) {
        return Portfolio.annualizedExposureFactor(marketId, maturityTimestamp);
    }

    function activatePool(uint128 id, uint128 marketId, uint32 maturityTimestamp) external {
        Portfolio.load(id).activatePool(marketId, maturityTimestamp);
    }

    function deactivatePool(uint128 id, uint128 marketId, uint32 maturityTimestamp) external {
        Portfolio.load(id).deactivatePool(marketId, maturityTimestamp);
    }

    function closeAccount(uint128 id, address poolAddress) external {
        Portfolio.load(id).closeAccount(poolAddress);
    }

    function updatePosition(uint128 id, uint128 marketId, uint32 maturityTimestamp, int256 baseDelta, int256 quoteDelta) external {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.updatePosition(marketId, maturityTimestamp, baseDelta, quoteDelta);
    }

    function settle(uint128 id, uint128 marketId, uint32 maturityTimestamp) external returns (int256 settlementCashflow) {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.settle(marketId, maturityTimestamp);
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
    using Portfolio for Portfolio.Data;
    using RateOracleReader for RateOracleReader.Data;

    ExposePortfolio portfolio;

    MockRateOracle mockRateOracle;
    MockPool mockPool;
    uint256 public maturityTimestamp;
    uint32 currentTimestamp;

    uint128 internal constant ONE_YEAR = 3139000;
    uint128 internal constant marketId = 100;
    uint128 internal constant accountId = 200;
    bytes32 internal constant portfolioSlot = keccak256(abi.encode("xyz.voltz.Portfolio", accountId));

    function setUp() public virtual {
        currentTimestamp = uint32(block.timestamp);

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
        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL, 0);
    }

    function test_GetAccountUnrealizedPnLWithTraderPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + 31540000;
        uint32 maturityTimestamp2 = currentTimestamp + 31540000 / 2;
        uint256 liqudityIndex = 1e27;
        uint256 gwap1 = 0.3e18; // 30% -> 1.3 * base
        uint256 gwap2 = 0.05e18; // 5% ->1 + (0.05 * 1/2) * base

        portfolio.updatePosition(accountId, marketId, maturityTimestamp1, 1000 * 1e18, 500 * 1e18);

        portfolio.updatePosition(accountId, marketId, maturityTimestamp2, 100 * 1e18, 20 * 1e18);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp1, gwap1);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp2, gwap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        // set gwap
        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL, 19225 * 1e17);
    }

    function test_GetAccountUnrealizedPnLWithLpPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + 31540000;
        uint32 maturityTimestamp2 = currentTimestamp + 31540000 / 2;
        uint256 liqudityIndex = 1e27;
        uint256 gwap1 = 0.3e18;
        uint256 gwap2 = 0.05e18;

        portfolio.activatePool(accountId, marketId, maturityTimestamp1);
        portfolio.activatePool(accountId, marketId, maturityTimestamp2);

        // same for both positions
        mockPool.setBalances(
            1500 * 1e18, // _baseBalancePool
            -210 * 1e18, // _quoteBalancePool
            0, // _unfilledBaseLong
            0 // _unfilledBaseShort
        );

        mockPool.setDatedIRSGwap(marketId, maturityTimestamp1, gwap1);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp2, gwap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        // set gwap
        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL, 30675 * 1e17);
    }

    function test_GetAccountUnrealizedPnLWithTraderAndLpPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + 31540000;
        uint32 maturityTimestamp2 = currentTimestamp + 31540000 / 2;
        uint256 liqudityIndex = 1e27;
        uint256 gwap1 = 0.3e18;
        uint256 gwap2 = 0.05e18;

        // trader position
        portfolio.updatePosition(accountId, marketId, maturityTimestamp1, 1000 * 1e18, 500 * 1e18);

        // LP position
        portfolio.activatePool(accountId, marketId, maturityTimestamp2);
        // same for both positions
        mockPool.setBalances(
            1500 * 1e18, // _baseBalancePool
            -210 * 1e18, // _quoteBalancePool
            0, // _unfilledBaseLong
            0 // _unfilledBaseShort
        );

        mockPool.setDatedIRSGwap(marketId, maturityTimestamp1, gwap1);
        mockPool.setDatedIRSGwap(marketId, maturityTimestamp2, gwap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        // set gwap
        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        // 1300 + 1950 + 500 - 210 = 3540
        // 0 + 1537.5 + 0 - 210 = 1327.5
        assertEq(unrealizedPnL, 48675 * 1e17);
    }

    function test_CreateNewPosition() public {
        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.updatePosition(accountId, 100, maturityTimestamp, 10, 20);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance, 10);
        assertEq(position.quoteBalance, 20);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp));
    }

    function test_UpdatePosition() public {
        // use previous setup
        test_CreateNewPosition();

        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.updatePosition(accountId, 100, maturityTimestamp, 10, 20);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance, 20);
        assertEq(position.quoteBalance, 40);
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

        int256 settlementCashflow = portfolio.settle(accountId, marketId, maturityTimestamp);
        assertEq(settlementCashflow, 10e18 + 20);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);
        assertEq(position.baseBalance, 0);
        assertEq(position.quoteBalance, 0);
    }

    function test_ActivatePool() public {
        portfolio.activatePool(accountId, marketId, 21988);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988));
    }

    function test_DeactivateActivePool() public {
        portfolio.activatePool(accountId, marketId, 21988);
        portfolio.deactivatePool(accountId, marketId, 21988);
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988));
    }

    function test_DeactivateInactivePool() public {
        portfolio.deactivatePool(accountId, marketId, 21988);
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988));
    }

    function test_SettleExistingPosition() public {
        test_CreateNewPosition();

        uint32 maturityTimestamp = currentTimestamp + 2;
        mockRateOracle.setLastUpdatedIndex(1e27);

        vm.warp(maturityTimestamp + 1);
        portfolio.updateCache(marketId, maturityTimestamp);

        int256 settlementCashflow = portfolio.settle(accountId, 100, maturityTimestamp);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance, 0);
        assertEq(position.quoteBalance, 0);
        assertEq(settlementCashflow, 1e19 + 20);
    }

    function test_AnnualizedExposureFactorBeforeMaturity() public {
        uint32 maturityTimestamp = currentTimestamp + 31540000;
        mockRateOracle.setLastUpdatedIndex(1e27);

        int256 factor = portfolio.annualizedExposureFactor(marketId, maturityTimestamp);

        assertEq(factor, 1e18);
    }

    function test_AnnualizedExposureFactorAfterMaturity() public {
        uint32 maturityTimestamp = currentTimestamp - 1;
        mockRateOracle.setLastUpdatedIndex(1e27);
        portfolio.updateCache(marketId, maturityTimestamp);

        int256 factor = portfolio.annualizedExposureFactor(marketId, maturityTimestamp);

        assertEq(factor, 0);
    }

    function test_AccountAnnualizedExposureTaker() public {
        uint32 maturityTimestamp = currentTimestamp + 31540000;

        portfolio.updatePosition(accountId, 100, maturityTimestamp, 10, 20);

        mockRateOracle.setLastUpdatedIndex(1e27);

        Account.Exposure[] memory exposures = portfolio.getAccountAnnualizedExposures(accountId, address(mockPool));

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, marketId);
        assertEq(exposures[0].filled, 1e19);
        assertEq(exposures[0].unfilledLong, 0);
        assertEq(exposures[0].unfilledShort, 0);
    }

    function test_AccountAnnualizedWithPosition() public {
        uint32 maturityTimestamp = currentTimestamp + 31540000;

        portfolio.updatePosition(accountId, 100, maturityTimestamp, 10, 20);
        mockPool.setBalances(15, 21, 2, -3);

        mockRateOracle.setLastUpdatedIndex(1e27);

        Account.Exposure[] memory exposures = portfolio.getAccountAnnualizedExposures(accountId, address(mockPool));

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, marketId);
        assertEq(exposures[0].filled, 2.5e19);
        assertEq(exposures[0].unfilledLong, 2e18);
        assertEq(exposures[0].unfilledShort, -3e18);
    }
}

pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../src/storage/Portfolio.sol";
import "../src/storage/PoolConfiguration.sol";
import "../src/storage/RateOracleReader.sol";
import "./mocks/MockRateOracle.sol";
import "./mocks/MockPool.sol";
import { UD60x18, ud, unwrap } from "../../lib/prb-math/src/UD60x18.sol";

contract ExposePortfolio {
    using Portfolio for Portfolio.Data;

    // Exposed functions
    function load(uint128 id) external pure returns (bytes32 s) {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        assembly {
            s := portfolio.slot
        }
    }

    // function loadRateIndexPreMaturity(uint128 id, uint256 maturityTimestamp) external view returns 
    //     (uint40 timestamp, UD60x18 index) {
    //     Portfolio.Data storage oracleData = Portfolio.load(id);
    //     Portfolio.PreMaturityData memory rateIndexOfMaturity = oracleData.rateIndexPreMaturity[maturityTimestamp];
    //     timestamp = rateIndexOfMaturity.lastKnownTimestamp;
    //     index = rateIndexOfMaturity.lastKnownIndex;
    // }

    // function loadRateIndexAtMaturity(uint128 id, uint256 maturityTimestamp) external view returns 
    //     (UD60x18 index) {
    //     Portfolio.Data storage oracleData = Portfolio.load(id);
    //     index = oracleData.rateIndexAtMaturity[maturityTimestamp];
    // }

    function create(uint128 id) external returns (bytes32 s) {
        Portfolio.Data storage portfolio = Portfolio.create(id);
        assembly {
            s := portfolio.slot
        }
    }

    function getAccountUnrealizedPnL(uint128 id, address poolAddress) external returns (int256) {
        Portfolio.load(id).getAccountUnrealizedPnL(poolAddress);
    }

    function baseToAnnualizedExposure(
        uint128 id,
        int256[] memory baseAmounts,
        uint128 marketId,
        uint256 maturityTimestamp
    ) external returns (int256[] memory exposures) {
        return Portfolio.baseToAnnualizedExposure(
            baseAmounts,
            marketId,
            maturityTimestamp
        );
    }

    // function getAccountAnnualizedExposures(uint128 id, uint256 poolAddress) 
    //     external returns (Account.Exposure[] memory exposures) {
    //     Portfolio.load(id).getAccountAnnualizedExposures(poolAddress);
    // }

    function closeAccount(uint128 id, address poolAddress) external {
        Portfolio.load(id).closeAccount(poolAddress);
    }

    function updatePosition(
        uint128 id,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseDelta,
        int256 quoteDelta
    ) external {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.updatePosition(
            marketId,
            maturityTimestamp,
            baseDelta,
            quoteDelta
        );
    }

    function settle(
        uint128 id,
        uint128 marketId,
        uint256 maturityTimestamp
    ) external returns (int256 settlementCashflow) {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.settle(
            marketId,
            maturityTimestamp
        );
    }
}

contract PortfolioTest is Test {
    using Portfolio for Portfolio.Data;

    ExposePortfolio portfolio;

    MockRateOracle mockRateOracle;
    MockPool mockPool;
    uint256 public maturityTimestamp;

    uint128 internal constant ONE_YEAR = 3139000;
    uint128 internal constant marketId = 100;
    uint128 internal constant accountId = 200;
    bytes32 internal constant portfolioSlot = keccak256(abi.encode("xyz.voltz.Portfolio", accountId));

    function setUp() public virtual {
        portfolio = new ExposePortfolio();

        mockPool = new MockPool();
        mockRateOracle = new MockRateOracle();

        RateOracleReader.create(100, address(mockRateOracle));
        //PoolConfiguration.set({poolAddress: address(mockPool)});
        maturityTimestamp = block.timestamp + ONE_YEAR;

        portfolio.create(100);
    }

    function test_create() public {
        bytes32 slot = portfolio.load(accountId);
        assertEq(slot, portfolioSlot);
    }

    function test_GetAccountUnrealizedPnLNoActivPositions() public {
        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool));

        assertEq(unrealizedPnL, 0);
    }
}
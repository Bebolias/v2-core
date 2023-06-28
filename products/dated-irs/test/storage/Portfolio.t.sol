/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "../../src/storage/Portfolio.sol";
import "../../src/storage/MarketConfiguration.sol";
import "../../src/storage/RateOracleReader.sol";
import "../mocks/MockRateOracle.sol";
import "../mocks/MockPool.sol";
import "@voltz-protocol/core/src/storage/Account.sol";
import "@voltz-protocol/core/src/storage/MarketRiskConfiguration.sol";
import "@voltz-protocol/core/src/interfaces/IRiskConfigurationModule.sol";
import "@voltz-protocol/core/src/interfaces/IProductModule.sol";
import { UD60x18, ud, unwrap as uUnwrap } from "@prb/math/UD60x18.sol";
import { sd } from "@prb/math/SD59x18.sol";

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

    function setProductConfig(address pool) external {
        ProductConfiguration.set(ProductConfiguration.Data({ productId: 1, coreProxy: address(12), poolAddress: pool }));
    }

    function loadOrCreate(uint128 id) external returns (bytes32 s) {
        Portfolio.Data storage portfolio = Portfolio.loadOrCreate(id);
        assembly {
            s := portfolio.slot
        }
    }

    function exists(uint128 id) external returns (bool) {
        Portfolio.Data storage portfolio = Portfolio.exists(id);
        return portfolio.accountId == id;
    }

    function getAccountAnnualizedExposures(
        uint128 id,
        address poolAddress,
        address collateralType
    )
        external
        returns (Account.Exposure[] memory)
    {
        return Portfolio.load(id).getAccountAnnualizedExposures(poolAddress, collateralType);
    }

    function getAccountUnrealizedPnL(uint128 id, address poolAddress, address collateralType) external returns (int256) {
        return Portfolio.load(id).getAccountUnrealizedPnL(poolAddress, collateralType);
    }

    function annualizedExposureFactor(uint128 marketId, uint32 maturityTimestamp) external returns (UD60x18) {
        return Portfolio.annualizedExposureFactor(marketId, maturityTimestamp);
    }

    function baseToAnnualizedExposure(
        int256[] memory baseAmounts,
        uint128 marketId,
        uint32 maturityTimestamp
    )
        external
        returns (int256[] memory)
    {
        return Portfolio.baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp);
    }

    function activateMarketMaturity(uint128 id, uint128 marketId, uint32 maturityTimestamp) external {
        Portfolio.load(id).activateMarketMaturity(marketId, maturityTimestamp);
    }

    function deactivateMarketMaturity(uint128 id, uint128 marketId, uint32 maturityTimestamp) external {
        Portfolio.load(id).deactivateMarketMaturity(marketId, maturityTimestamp);
    }

    function closeAccount(uint128 id, address poolAddress, address collateralType) external {
        Portfolio.load(id).closeAccount(poolAddress, collateralType);
    }

    function getMarketAndMaturity(
        uint128 id,
        uint256 index,
        address collateralType
    )
        external
        view
        returns (uint128 marketId, uint32 maturityTimestamp)
    {
        (marketId, maturityTimestamp) = Portfolio.load(id).getMarketAndMaturity(index, collateralType);
    }

    function updatePosition(uint128 id, uint128 marketId, uint32 maturityTimestamp, int256 baseDelta, int256 quoteDelta) external {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.updatePosition(marketId, maturityTimestamp, baseDelta, quoteDelta);
    }

    function settle(
        uint128 id,
        uint128 marketId,
        uint32 maturityTimestamp,
        address poolAddress
    )
        external
        returns (int256 settlementCashflow)
    {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.settle(marketId, maturityTimestamp, poolAddress);
    }

    function computeUnwindQuote(
        uint128 marketId,
        uint32 maturityTimestamp,
        address poolAddress,
        int256 baseAmount
    )
        external
        view
        returns (int256 unwindQuote)
    {
        unwindQuote = Portfolio.computeUnwindQuote(marketId, maturityTimestamp, poolAddress, baseAmount);
    }

    function updateRateIndexAtMaturityCache(uint128 id, uint32 maturityTimestamp) external {
        RateOracleReader.load(id).updateRateIndexAtMaturityCache(maturityTimestamp);
    }

    function createRateOracle(uint128 marketId, address rateOracleAddress, uint256 maturityIndexCachingWindowInSeconds) external {
        RateOracleReader.set(marketId, rateOracleAddress, maturityIndexCachingWindowInSeconds);
    }

    function setMarket(uint128 marketId, address quoteToken) external {
        MarketConfiguration.set(MarketConfiguration.Data({ marketId: marketId, quoteToken: quoteToken }));
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

    function isActiveMarketAndMaturity(
        uint128 id,
        uint128 marketId,
        uint32 maturityTimestamp,
        address collateralType
    )
        external
        returns (bool)
    {
        Portfolio.Data storage portfolio = Portfolio.load(id);
        return portfolio.activeMarketsAndMaturities[collateralType].contains((marketId << 32) | maturityTimestamp);
    }
}

contract PortfolioTest is Test {
    using { uUnwrap } for UD60x18;
    using Portfolio for Portfolio.Data;
    using RateOracleReader for RateOracleReader.Data;

    ExposePortfolio portfolio;

    MockRateOracle mockRateOracle;
    MockPool mockPool;
    uint32 currentTimestamp;

    address constant MOCK_COLLATERAL_TYPE = 0x1122334455667788990011223344556677889900;
    uint32 internal constant ONE_YEAR = 31536000;
    uint128 internal constant marketId = 100;
    uint128 internal constant accountId = 200;
    bytes32 internal constant portfolioSlot = keccak256(abi.encode("xyz.voltz.Portfolio", accountId));
    MarketRiskConfiguration.Data mockCoreMarketConfig =
        MarketRiskConfiguration.Data({ productId: 0, marketId: marketId, riskParameter: sd(0), twapLookbackWindow: 86400 });

    function setUp() public virtual {
        currentTimestamp = Time.blockTimestampTruncated();

        mockPool = new MockPool();
        mockRateOracle = new MockRateOracle();

        portfolio = new ExposePortfolio();
        portfolio.loadOrCreate(accountId);
        portfolio.createRateOracle(marketId, address(mockRateOracle), 3600);

        portfolio.setMarket(marketId, MOCK_COLLATERAL_TYPE);
    }

    function test_LoadAtCorrectSlot() public {
        bytes32 slot = portfolio.load(accountId);
        assertEq(slot, portfolioSlot);
    }

    function test_LoadOrCreatePortfolio() public {
        bytes32 slot = portfolio.loadOrCreate(300);
        assertEq(slot, keccak256(abi.encode("xyz.voltz.Portfolio", 300)));
    }

    function test_ExistsPortfolio() public {
        bytes32 slot = portfolio.loadOrCreate(300);
        assertEq(portfolio.exists(300), true);
    }

    function test_RevertWhen_ExistsNoPortfolio() public {
        vm.expectRevert(abi.encodeWithSelector(Portfolio.PortfolioNotFound.selector, 300));
        portfolio.exists(300);
    }

    function test_GetAccountUnrealizedPnLNoActivPositions() public {
        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        assertEq(unrealizedPnL, 0);
    }

    function test_GetAccountUnrealizedPnLWithTraderPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + ONE_YEAR;
        uint32 maturityTimestamp2 = currentTimestamp + ONE_YEAR / 2;
        uint256 liqudityIndex = 1e27;
        UD60x18 twap1 = ud(0.3e18); // 30% -> 1.3 * base
        UD60x18 twap2 = ud(0.05e18); // 5% ->1 + (0.05 * 1/2) * base

        portfolio.updatePosition(accountId, marketId, maturityTimestamp1, 1000 * 1e18, 500 * 1e18);
        portfolio.updatePosition(accountId, marketId, maturityTimestamp2, 100 * 1e18, 20 * 1e18);
        mockPool.setDatedIRSTwap(marketId, maturityTimestamp1, twap1);
        mockPool.setDatedIRSTwap(marketId, maturityTimestamp2, twap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IRiskConfigurationModule.getMarketRiskConfiguration.selector, 0, marketId),
            abi.encode(mockCoreMarketConfig)
        );

        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        assertEq(unrealizedPnL, 19225 * 1e17);
    }

    function test_GetAccountUnrealizedPnLWithLpPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + ONE_YEAR;
        uint32 maturityTimestamp2 = currentTimestamp + ONE_YEAR / 2;
        uint256 liqudityIndex = 1e27;
        UD60x18 twap1 = ud(0.3e18);
        UD60x18 twap2 = ud(0.05e18);

        portfolio.activateMarketMaturity(accountId, marketId, maturityTimestamp1);
        portfolio.activateMarketMaturity(accountId, marketId, maturityTimestamp2);

        // same for both positions
        mockPool.setBalances(
            1500 * 1e18, // _baseBalancePool
            -210 * 1e18, // _quoteBalancePool
            0, // _unfilledBaseLong
            0 // _unfilledBaseShort
        );

        mockPool.setDatedIRSTwap(marketId, maturityTimestamp1, twap1);
        mockPool.setDatedIRSTwap(marketId, maturityTimestamp2, twap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IRiskConfigurationModule.getMarketRiskConfiguration.selector, 0, marketId),
            abi.encode(mockCoreMarketConfig)
        );

        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        assertEq(unrealizedPnL, 30675 * 1e17);
    }

    function test_GetAccountUnrealizedPnLWithTraderAndLpPositions() public {
        uint32 maturityTimestamp1 = currentTimestamp + ONE_YEAR;
        uint32 maturityTimestamp2 = currentTimestamp + ONE_YEAR / 2;
        uint256 liqudityIndex = 1e27;
        UD60x18 twap1 = ud(0.3e18);
        UD60x18 twap2 = ud(0.05e18);

        // trader position
        portfolio.updatePosition(accountId, marketId, maturityTimestamp1, 1000 * 1e18, 500 * 1e18);

        // LP position
        portfolio.activateMarketMaturity(accountId, marketId, maturityTimestamp2);
        // same for both positions
        mockPool.setBalances(
            1500 * 1e18, // _baseBalancePool
            -210 * 1e18, // _quoteBalancePool
            0, // _unfilledBaseLong
            0 // _unfilledBaseShort
        );

        mockPool.setDatedIRSTwap(marketId, maturityTimestamp1, twap1);
        mockPool.setDatedIRSTwap(marketId, maturityTimestamp2, twap2);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IRiskConfigurationModule.getMarketRiskConfiguration.selector, 0, marketId),
            abi.encode(mockCoreMarketConfig)
        );

        int256 unrealizedPnL = portfolio.getAccountUnrealizedPnL(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        // 1300 + 1950 + 500 - 210 = 3540
        // 0 + 1537.5 + 0 - 210 = 1327.5
        assertEq(unrealizedPnL, 48675 * 1e17);
    }

    function test_ComputeUnwindQuote() public {
        uint32 maturityTimestamp = currentTimestamp + ONE_YEAR;
        uint256 liqudityIndex = 1e27;
        UD60x18 twap = ud(0.3e18);

        mockPool.setDatedIRSTwap(marketId, maturityTimestamp, twap);

        mockRateOracle.setLastUpdatedIndex(liqudityIndex);

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IRiskConfigurationModule.getMarketRiskConfiguration.selector, 0, marketId),
            abi.encode(mockCoreMarketConfig)
        );

        int256 unrealizedPnL = portfolio.computeUnwindQuote(marketId, maturityTimestamp, address(mockPool), 1000);

        assertEq(unrealizedPnL, 1300);
    }

    function test_CreateNewPosition() public {
        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.updatePosition(accountId, marketId, maturityTimestamp, 10, 20);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance, 10);
        assertEq(position.quoteBalance, 20);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp, MOCK_COLLATERAL_TYPE));
    }

    function test_UpdatePosition() public {
        // use previous setup
        test_CreateNewPosition();

        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.updatePosition(accountId, marketId, maturityTimestamp, 10, 20);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance, 20);
        assertEq(position.quoteBalance, 40);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp, MOCK_COLLATERAL_TYPE));
    }

    function test_CloseAccountWithoutClosingInMarket() public {
        test_CreateNewPosition();
        uint32 maturityTimestamp = currentTimestamp + 2;
        portfolio.setProductConfig(address(mockPool));

        vm.mockCall(
            address(12),
            abi.encodeWithSelector(IProductModule.propagateTakerOrder.selector, accountId, 1, marketId, MOCK_COLLATERAL_TYPE, 0),
            abi.encode(0, 0)
        );

        vm.expectCall(
            address(mockPool), 0, abi.encodeWithSelector(mockPool.executeDatedTakerOrder.selector, marketId, maturityTimestamp, -10)
        );
        portfolio.closeAccount(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        // market not deactivated, executed amounts != position amounts
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp, MOCK_COLLATERAL_TYPE));
    }

    function test_FullyCloseTraderAccount() public {
        uint32 maturityTimestamp = currentTimestamp + 2;

        portfolio.updatePosition(accountId, marketId, maturityTimestamp, 10, 10);

        portfolio.setProductConfig(address(mockPool));
        vm.mockCall(
            address(12),
            abi.encodeWithSelector(IProductModule.propagateTakerOrder.selector, accountId, 1, marketId, MOCK_COLLATERAL_TYPE, 0),
            abi.encode(0, 0)
        );

        vm.expectCall(
            address(mockPool), 0, abi.encodeWithSelector(mockPool.executeDatedTakerOrder.selector, marketId, maturityTimestamp, -10)
        );
        portfolio.closeAccount(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        // market deactivated, executed amounts == position amounts
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, maturityTimestamp, MOCK_COLLATERAL_TYPE));
    }

    function test_Settle() public {
        test_CreateNewPosition();
        uint32 maturityTimestamp = currentTimestamp + 2;

        vm.warp(maturityTimestamp + 1);

        mockRateOracle.setLastUpdatedIndex(1e27);
        portfolio.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        int256 settlementCashflow = portfolio.settle(accountId, marketId, maturityTimestamp, address(mockPool));
        assertEq(settlementCashflow, 30);

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);
        assertEq(position.baseBalance, 0);
        assertEq(position.quoteBalance, 0);
    }

    function test_RevertWhen_SettleBeforeMaturity() public {
        uint32 maturityTimestamp = currentTimestamp + 2;

        vm.expectRevert(abi.encodeWithSelector(Portfolio.SettlementBeforeMaturity.selector, marketId, maturityTimestamp, accountId));
        portfolio.settle(accountId, marketId, maturityTimestamp, address(mockPool));
    }

    function test_ActivateMarket() public {
        portfolio.activateMarketMaturity(accountId, marketId, 21988);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988, MOCK_COLLATERAL_TYPE));
    }

    function test_RevertWhen_ActivateUnknownMarket() public {
        vm.expectRevert(abi.encodeWithSelector(Portfolio.UnknownMarket.selector, 47));
        portfolio.activateMarketMaturity(accountId, 47, 21988);
    }

    function test_GetMarketAndMaturity() public {
        portfolio.activateMarketMaturity(accountId, marketId, 21988);
        assertTrue(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988, MOCK_COLLATERAL_TYPE));

        (uint128 _marketId, uint32 _maturityTimestamp) = portfolio.getMarketAndMaturity(accountId, 1, MOCK_COLLATERAL_TYPE);
        assertEq(_marketId, marketId);
        assertEq(_maturityTimestamp, 21988);
    }

    function test_DeactivateActivePool() public {
        portfolio.activateMarketMaturity(accountId, marketId, 21988);
        portfolio.deactivateMarketMaturity(accountId, marketId, 21988);
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988, MOCK_COLLATERAL_TYPE));
    }

    function test_DeactivateInactivePool() public {
        portfolio.deactivateMarketMaturity(accountId, marketId, 21988);
        assertFalse(portfolio.isActiveMarketAndMaturity(accountId, marketId, 21988, MOCK_COLLATERAL_TYPE));
    }

    function test_SettleExistingPosition() public {
        test_CreateNewPosition();

        uint32 maturityTimestamp = currentTimestamp + 2;
        mockRateOracle.setLastUpdatedIndex(1e27);

        vm.warp(maturityTimestamp + 1);
        portfolio.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        int256 settlementCashflow = portfolio.settle(accountId, marketId, maturityTimestamp, address(mockPool));

        Position.Data memory position = portfolio.getPositionData(accountId, marketId, maturityTimestamp);

        assertEq(position.baseBalance, 0);
        assertEq(position.quoteBalance, 0);
        assertEq(settlementCashflow, 30);
    }

    function test_AnnualizedExposureFactorBeforeMaturity() public {
        uint32 maturityTimestamp = currentTimestamp + ONE_YEAR;
        mockRateOracle.setLastUpdatedIndex(1e27);

        UD60x18 factor = portfolio.annualizedExposureFactor(marketId, maturityTimestamp);

        assertEq(factor.uUnwrap(), 1e18);
    }

    function test_AnnualizedExposureFactorAfterMaturity() public {
        uint32 maturityTimestamp = currentTimestamp - 1;
        mockRateOracle.setLastUpdatedIndex(1e27);
        portfolio.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        UD60x18 factor = portfolio.annualizedExposureFactor(marketId, maturityTimestamp);

        assertEq(factor.uUnwrap(), 0);
    }

    function test_BaseAnnualizedExposureBeforeMaturity() public {
        uint32 maturityTimestamp = currentTimestamp + ONE_YEAR;
        mockRateOracle.setLastUpdatedIndex(1.01e27);

        int256[] memory baseAmounts = new int[](2);
        baseAmounts[0] = 1000;
        baseAmounts[1] = 10000;

        int256[] memory exposures = portfolio.baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp);

        assertEq(exposures[0], 1010);
        assertEq(exposures[1], 10100);
    }

    function test_BaseAnnualizedExposureAfterMaturity() public {
        uint32 maturityTimestamp = currentTimestamp - 1;
        mockRateOracle.setLastUpdatedIndex(1e27);
        portfolio.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        int256[] memory baseAmounts = new int[](2);
        baseAmounts[0] = 1000;
        baseAmounts[1] = 10000;

        int256[] memory exposures = portfolio.baseToAnnualizedExposure(baseAmounts, marketId, maturityTimestamp);

        assertEq(exposures[0], 0);
        assertEq(exposures[1], 0);
    }

    function test_AccountAnnualizedExposureTaker() public {
        uint32 maturityTimestamp = currentTimestamp + ONE_YEAR;

        portfolio.updatePosition(accountId, marketId, maturityTimestamp, 10 * 1e6, 20 * 1e6);

        mockRateOracle.setLastUpdatedIndex(1e27);

        Account.Exposure[] memory exposures =
            portfolio.getAccountAnnualizedExposures(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, marketId);
        assertEq(exposures[0].filled, 1e7);
        assertEq(exposures[0].unfilledLong, 0);
        assertEq(exposures[0].unfilledShort, 0);
    }

    function test_AccountAnnualizedWithPosition() public {
        uint32 maturityTimestamp = currentTimestamp + ONE_YEAR;

        portfolio.updatePosition(accountId, marketId, maturityTimestamp, 10, 20);
        mockPool.setBalances(15, 21, 2, 3);

        mockRateOracle.setLastUpdatedIndex(1e27);

        Account.Exposure[] memory exposures =
            portfolio.getAccountAnnualizedExposures(accountId, address(mockPool), MOCK_COLLATERAL_TYPE);

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, marketId);
        assertEq(exposures[0].filled, 25);
        assertEq(exposures[0].unfilledLong, 2);
        assertEq(exposures[0].unfilledShort, 3);
    }
}

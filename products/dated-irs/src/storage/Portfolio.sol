/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "@voltz-protocol/util-contracts/src/helpers/Pack.sol";
import "@voltz-protocol/core/src/interfaces/IProductModule.sol";
import "./Position.sol";
import "./RateOracleReader.sol";
import "./MarketConfiguration.sol";
import "./ProductConfiguration.sol";
import "../interfaces/IPool.sol";
import "@voltz-protocol/core/src/storage/Account.sol";
import "@voltz-protocol/core/src/interfaces/IRiskConfigurationModule.sol";
import { UD60x18, UNIT, unwrap } from "@prb/math/UD60x18.sol";
import { SD59x18 } from "@prb/math/SD59x18.sol";
import { mulUDxUint, mulUDxInt } from "@voltz-protocol/util-contracts/src/helpers/PrbMathHelper.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library Portfolio {
    using Portfolio for Portfolio.Data;
    using Position for Position.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU256 for uint256;
    using RateOracleReader for RateOracleReader.Data;

    /**
     * @dev Thrown when a portfolio cannot be found.
     */
    error PortfolioNotFound(uint128 accountId);

    /**
     * @dev Thrown when an account exceeds the positions limit.
     */
    error TooManyTakerPositions(uint128 accountId);

    /**
     * @notice Emitted when attempting to settle before maturity
     */
    error SettlementBeforeMaturity(uint128 marketId, uint32 maturityTimestamp, uint256 accountId);
    error UnknownMarket(uint128 marketId);

    /**
     * @notice Emitted when a new product is registered in the protocol.
     * @param accountId The id of the account.
     * @param marketId The id of the market.
     * @param maturityTimestamp The maturity timestamp of the position.
     * @param baseDelta The delta in position base balance.
     * @param quoteDelta The delta in position quote balance.
     * @param blockTimestamp The current block timestamp.
     */
    event ProductPositionUpdated(
        uint128 indexed accountId,
        uint128 indexed marketId,
        uint32 indexed maturityTimestamp,
        int256 baseDelta,
        int256 quoteDelta,
        uint256 blockTimestamp
    );

    struct Data {
        /**
         * @dev Numeric identifier for the account that owns the portfolio.
         * @dev Since a given account can only own a single portfolio in a given dated product
         * the id of the portfolio is the same as the id of the account
         * @dev There cannot be an account and hence dated portfolio with id zero
         */
        uint128 accountId;
        /**
         * @dev marketId (e.g. aUSDC lend) --> maturityTimestamp (e.g. 31st Dec 2023) --> Position object with filled
         * balances
         */
        mapping(uint128 => mapping(uint32 => Position.Data)) positions;
        /**
         * @dev Mapping from settlementToken to an
         * array of marketId (e.g. aUSDC lend) and activeMaturities (e.g. 31st Dec 2023)
         * in which the account has active positions
         */
        mapping(address => SetUtil.UintSet) activeMarketsAndMaturities;
    }

    /**
     * @dev Returns the portfolio stored at the specified portfolio id
     * @dev Same as account id of the account that owns the portfolio of dated irs positions
     */
    function load(uint128 accountId) internal pure returns (Data storage portfolio) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Portfolio", accountId));
        assembly {
            portfolio.slot := s
        }
    }

    function loadOrCreate(uint128 id) internal returns (Data storage portfolio) {
        portfolio = load(id);
        if (portfolio.accountId == 0)  {
            portfolio.accountId = id;
        }
    }

    /**
     * @dev Reverts if the portfolio does not exist with appropriate error. Otherwise, returns the portfolio.
     */
    function exists(uint128 id) internal view returns (Data storage portfolio) {
        portfolio = load(id);
        if (portfolio.accountId != id) {
            revert PortfolioNotFound(id);
        }
    }

    // todo: consider breaking below functions into pure functions
    function computeUnrealizedLoss(
        uint128 marketId,
        uint32 maturityTimestamp,
        address poolAddress,
        int256 baseBalance,
        int256 quoteBalance
    ) internal view returns (uint256 unrealizedLoss) {
        int256 unwindQuote = computeUnwindQuote(marketId, maturityTimestamp, poolAddress, baseBalance);
        int256 unrealizedPnL = quoteBalance + unwindQuote;

        if (unrealizedPnL < 0) {
            // todo: check if safecasting with .Uint() is necessary
            unrealizedLoss = uint256(-unrealizedPnL);
        }
    }

    function computeUnwindQuote(
        uint128 marketId,
        uint32 maturityTimestamp,
        address poolAddress,
        int256 baseAmount
    )
        internal
        view
        returns (int256 unwindQuote)
    {
        UD60x18 timeDeltaAnnualized = Time.timeDeltaAnnualized(maturityTimestamp);

        UD60x18 currentLiquidityIndex = RateOracleReader.load(marketId).getRateIndexCurrent();

        address coreProxy = ProductConfiguration.getCoreProxyAddress();
        uint128 productId = ProductConfiguration.getProductId();
        uint32 lookbackWindow =
            IRiskConfigurationModule(coreProxy).getMarketRiskConfiguration(productId, marketId).twapLookbackWindow;

        UD60x18 twap = IPool(poolAddress).getAdjustedDatedIRSTwap(marketId, maturityTimestamp, baseAmount, lookbackWindow);

        unwindQuote = mulUDxInt(twap.mul(timeDeltaAnnualized).add(UNIT), mulUDxInt(currentLiquidityIndex, baseAmount));
    }

    /**
     * @dev in context of interest rate swaps, base refers to scaled variable tokens (e.g. scaled virtual aUSDC)
     * @dev in order to derive the annualized exposure of base tokens in quote terms (i.e. USDC), we need to
     * first calculate the (non-annualized) exposure by multiplying the baseAmount by the current liquidity index of the
     * underlying rate oracle (e.g. aUSDC lend rate oracle)
     */
    function annualizedExposureFactor(uint128 marketId, uint32 maturityTimestamp) internal view returns (UD60x18 factor) {
        UD60x18 currentLiquidityIndex = RateOracleReader.load(marketId).getRateIndexCurrent();
        UD60x18 timeDeltaAnnualized = Time.timeDeltaAnnualized(maturityTimestamp);
        factor = currentLiquidityIndex.mul(timeDeltaAnnualized);
    }

    function baseToAnnualizedExposure(
        int256[] memory baseAmounts,
        uint128 marketId,
        uint32 maturityTimestamp
    )
        internal
        view
        returns (int256[] memory exposures)
    {
        exposures = new int256[](baseAmounts.length);
        UD60x18 factor = annualizedExposureFactor(marketId, maturityTimestamp);

        for (uint256 i = 0; i < baseAmounts.length; i++) {
            exposures[i] = mulUDxInt(factor, baseAmounts[i]);
        }
    }

    function removeEmptySlotsFromExposuresArray(
        Account.Exposure[] memory exposures,
        uint256 length
    ) internal view returns (Account.Exposure[] memory exposuresWithoutEmptySlots) {
        // todo: consider into a utility library
        require(exposures.length >= length);
        exposuresWithoutEmptySlots = new Account.Exposure[](length);
        for (uint256 i = 0; i < length; i++) {
            exposuresWithoutEmptySlots[i] = exposures[i];
        }
    }

    struct CollateralExposureState {
        uint128 productId;
        uint256 poolsCount;
        uint256 takerExposuresLength;
        uint256 makerExposuresLowerAndUpperLength;
        Account.Exposure[] takerExposuresWithEmptySlots;
        Account.Exposure[] makerExposuresLowerWithEmptySlots;
       Account.Exposure[] makerExposuresUpperWithEmptySlots;
    }

    struct PoolExposureState {
        uint128 marketId;
        uint32 maturityTimestamp;
        int256 baseBalance;
        int256 baseBalancePool;
        int256 quoteBalance;
        int256 quoteBalancePool;
        uint256 unfilledBaseLong;
        uint256 unfilledQuoteLong;
        uint256 unfilledBaseShort;
        uint256 unfilledQuoteShort;
        UD60x18 _annualizedExposureFactor;
    }

    function getAccountTakerAndMakerExposuresWithEmptySlots(
        Data storage self,
        address poolAddress,
        address collateralType
    ) internal view returns (Account.Exposure[] memory, Account.Exposure[] memory, Account.Exposure[] memory, uint256, uint256) {

        CollateralExposureState memory ces = CollateralExposureState({
            productId: ProductConfiguration.getProductId(),
            poolsCount: self.activeMarketsAndMaturities[collateralType].length(),
            takerExposuresLength: 0,
            makerExposuresLowerAndUpperLength: 0,
            takerExposuresWithEmptySlots: new Account.Exposure[](self.activeMarketsAndMaturities[collateralType].length()),
            makerExposuresLowerWithEmptySlots: new Account.Exposure[](self.activeMarketsAndMaturities[collateralType].length()),
            makerExposuresUpperWithEmptySlots: new Account.Exposure[](self.activeMarketsAndMaturities[collateralType].length())
        });


        for (uint256 i = 0; i < ces.poolsCount; i++) {
            PoolExposureState memory pes = self.getPoolExposureState(
                i + 1,
                collateralType,
                poolAddress
            );

            if (pes.unfilledBaseLong == 0 && pes.unfilledBaseShort == 0) {
                // no unfilled exposures => only consider taker exposures
                uint256 unrealizedLoss = computeUnrealizedLoss(
                    pes.marketId,
                    pes.maturityTimestamp,
                    poolAddress,
                    pes.baseBalance + pes.baseBalancePool,
                    pes.quoteBalance + pes.quoteBalancePool
                );
                ces.takerExposuresWithEmptySlots[ces.takerExposuresLength] = Account.Exposure({
                    productId: ces.productId,
                    marketId: pes.marketId,
                    annualizedNotional: mulUDxInt(pes._annualizedExposureFactor, pes.baseBalance + pes.baseBalancePool),
                    unrealizedLoss: unrealizedLoss
                });
                ces.takerExposuresLength = ces.takerExposuresLength + 1;
            } else {
                // unfilled exposures => consider maker lower
                uint256 unrealizedLossLower = computeUnrealizedLoss(
                    pes.marketId,
                    pes.maturityTimestamp,
                    poolAddress,
                    pes.baseBalance + pes.baseBalancePool - pes.unfilledBaseShort.toInt(),
                    pes.quoteBalance + pes.quoteBalancePool + pes.unfilledQuoteShort.toInt()
                );
                ces.makerExposuresLowerWithEmptySlots[ces.makerExposuresLowerAndUpperLength] = Account.Exposure({
                    productId: ces.productId,
                    marketId: pes.marketId,
                    annualizedNotional: mulUDxInt(
                        pes._annualizedExposureFactor, 
                        pes.baseBalance + pes.baseBalancePool + pes.unfilledBaseShort.toInt()
                    ),
                    unrealizedLoss: unrealizedLossLower
                });
                uint256 unrealizedLossUpper = computeUnrealizedLoss(
                    pes.marketId,
                    pes.maturityTimestamp,
                    poolAddress,
                    pes.baseBalance + pes.baseBalancePool + pes.unfilledBaseLong.toInt(),
                    pes.quoteBalance + pes.quoteBalancePool - pes.unfilledQuoteLong.toInt()
                );
                ces.makerExposuresUpperWithEmptySlots[ces.makerExposuresLowerAndUpperLength] = Account.Exposure({
                    productId: ces.productId,
                    marketId: pes.marketId,
                    annualizedNotional: mulUDxInt(
                        pes._annualizedExposureFactor,
                        pes.baseBalance + pes.baseBalancePool + pes.unfilledBaseLong.toInt()
                    ),
                    unrealizedLoss: unrealizedLossUpper
                });
                ces.makerExposuresLowerAndUpperLength = ces.makerExposuresLowerAndUpperLength + 1;
            }

        }

        return (
            ces.takerExposuresWithEmptySlots,
            ces.makerExposuresLowerWithEmptySlots,
            ces.makerExposuresUpperWithEmptySlots,
            ces.takerExposuresLength,
            ces.makerExposuresLowerAndUpperLength
        );
    }

    function getPoolExposureState(
        Data storage self,
        uint256 index,
        address collateralType,
        address poolAddress
    ) internal view returns (PoolExposureState memory pes) {
        (pes.marketId, pes.maturityTimestamp) = self.getMarketAndMaturity(index, collateralType);

        pes.baseBalance = self.positions[pes.marketId][pes.maturityTimestamp].baseBalance;
        pes.quoteBalance = self.positions[pes.marketId][pes.maturityTimestamp].quoteBalance;
        (pes.baseBalancePool,pes.quoteBalancePool) = IPool(poolAddress).getAccountFilledBalances(
            pes.marketId, pes.maturityTimestamp, self.accountId);
        (pes.unfilledBaseLong, pes.unfilledQuoteLong, pes.unfilledBaseShort, pes.unfilledQuoteShort) =
            IPool(poolAddress).getAccountUnfilledBaseAndQuote(pes.marketId, pes.maturityTimestamp, self.accountId);
        pes._annualizedExposureFactor = annualizedExposureFactor(pes.marketId, pes.maturityTimestamp);
    }

    function getAccountTakerAndMakerExposures(
        Data storage self,
        address poolAddress,
        address collateralType
    )
        internal
        view
        returns (
            Account.Exposure[] memory takerExposures,
            Account.Exposure[] memory makerExposuresLower,
            Account.Exposure[] memory makerExposuresUpper
        )
    {

        (
            Account.Exposure[] memory takerExposuresPadded,
            Account.Exposure[] memory makerExposuresLowerPadded,
            Account.Exposure[] memory makerExposuresUpperPadded,
            uint256 takerExposuresLength,
            uint256 makerExposuresLowerAndUpperLength
        ) = getAccountTakerAndMakerExposuresWithEmptySlots(self, poolAddress, collateralType);

        takerExposures = removeEmptySlotsFromExposuresArray(takerExposuresPadded, takerExposuresLength);
        makerExposuresLower = removeEmptySlotsFromExposuresArray(makerExposuresLowerPadded, makerExposuresLowerAndUpperLength);
        makerExposuresUpper = removeEmptySlotsFromExposuresArray(makerExposuresUpperPadded, makerExposuresLowerAndUpperLength);

        return (takerExposures, makerExposuresLower, makerExposuresUpper);
    }

    /**
     * @dev Fully Close all the positions owned by the account within the dated irs portfolio
     * poolAddress in which to close the account, note in the beginning we'll only have a single pool
     */
    function closeAccount(Data storage self, address poolAddress, address collateralType) internal {
        IPool pool = IPool(poolAddress);
        for (uint256 i = 1; i <= self.activeMarketsAndMaturities[collateralType].length(); i++) {
            (uint128 marketId, uint32 maturityTimestamp) = self.getMarketAndMaturity(i, collateralType);

            Position.Data storage position = self.positions[marketId][maturityTimestamp];

            pool.closeUnfilledBase(marketId, maturityTimestamp, self.accountId);

            // left-over exposure in pool
            (int256 filledBasePool,) = pool.getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);

            int256 unwindBase = -(position.baseBalance + filledBasePool);

            (int256 executedBaseAmount, int256 executedQuoteAmount) =
                pool.executeDatedTakerOrder(marketId, maturityTimestamp, unwindBase, 0);

            UD60x18 _annualizedExposureFactor = annualizedExposureFactor(marketId, maturityTimestamp);
            IProductModule(ProductConfiguration.getCoreProxyAddress()).propagateTakerOrder(
                self.accountId,
                ProductConfiguration.getProductId(),
                marketId,
                collateralType,
                mulUDxInt(_annualizedExposureFactor, executedBaseAmount)
            );

            position.update(executedBaseAmount, executedQuoteAmount);

            emit ProductPositionUpdated(
                self.accountId, marketId, maturityTimestamp, executedBaseAmount, executedQuoteAmount, block.timestamp
                );
        }
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function updatePosition(
        Data storage self,
        uint128 marketId,
        uint32 maturityTimestamp,
        int256 baseDelta,
        int256 quoteDelta
    )
        internal
    {
        Position.Data storage position = self.positions[marketId][maturityTimestamp];

        // register active market
        if (position.baseBalance == 0 && position.quoteBalance == 0) {
            self.activateMarketMaturity(marketId, maturityTimestamp);
        }

        position.update(baseDelta, quoteDelta);
        emit ProductPositionUpdated(self.accountId, marketId, maturityTimestamp, baseDelta, quoteDelta, block.timestamp);
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function settle(
        Data storage self,
        uint128 marketId,
        uint32 maturityTimestamp,
        address poolAddress
    )
        internal
        returns (int256 settlementCashflow)
    {
        if (maturityTimestamp > Time.blockTimestampTruncated()) {
            revert SettlementBeforeMaturity(marketId, maturityTimestamp, self.accountId);
        }

        Position.Data storage position = self.positions[marketId][maturityTimestamp];

        UD60x18 liquidityIndexMaturity = RateOracleReader.load(marketId).getRateIndexMaturity(maturityTimestamp);

        self.deactivateMarketMaturity(marketId, maturityTimestamp);

        IPool pool = IPool(poolAddress);

        (int256 filledBase, int256 filledQuote) = pool.getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);

        settlementCashflow =
            mulUDxInt(liquidityIndexMaturity, position.baseBalance + filledBase) + position.quoteBalance + filledQuote;

        emit ProductPositionUpdated(
            self.accountId, marketId, maturityTimestamp, -position.baseBalance, -position.quoteBalance, block.timestamp
            );
        position.update(-position.baseBalance, -position.quoteBalance);
    }

    /**
     * @dev set market and maturity as active
     * note this can also be called by the pool when a position is intitalised
     */
    function activateMarketMaturity(Data storage self, uint128 marketId, uint32 maturityTimestamp) internal {
        // check if market/maturity exist
        address collateralType = MarketConfiguration.load(marketId).quoteToken;
        if (collateralType == address(0)) {
            revert UnknownMarket(marketId);
        }
        uint256 marketMaturityPacked = Pack.pack(marketId, maturityTimestamp);
        if (!self.activeMarketsAndMaturities[collateralType].contains(marketMaturityPacked)) {
            if (
                self.activeMarketsAndMaturities[collateralType].length() >= 
                ProductConfiguration.load().takerPositionsPerAccountLimit
            ) {
                revert TooManyTakerPositions(self.accountId);
            }
            self.activeMarketsAndMaturities[collateralType].add(marketMaturityPacked);
        }
    }

    /**
     * @dev set market and maturity as inactive
     * note this can also be called by the pool when a position is settled
     */
    function deactivateMarketMaturity(Data storage self, uint128 marketId, uint32 maturityTimestamp) internal {
        uint256 marketMaturityPacked = Pack.pack(marketId, maturityTimestamp);
        address collateralType = MarketConfiguration.load(marketId).quoteToken;
        if (self.activeMarketsAndMaturities[collateralType].contains(marketMaturityPacked)) {
            self.activeMarketsAndMaturities[collateralType].remove(marketMaturityPacked);
        }
    }

    /**
     * @dev retreives marketId and maturityTimestamp from the list
     * of active markets and maturities associated with the collateral type
     */
    function getMarketAndMaturity(
        Data storage self,
        uint256 index,
        address collateralType
    )
        internal
        view
        returns (uint128 marketId, uint32 maturityTimestamp)
    {
        uint256 marketMaturityPacked = self.activeMarketsAndMaturities[collateralType].valueAt(index);
        (marketId, maturityTimestamp) = Pack.unpack(marketMaturityPacked);
    }
}

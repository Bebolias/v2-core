// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "@voltz-protocol/util-contracts/src/helpers/Pack.sol";
import "./Position.sol";
import "./RateOracleReader.sol";
import "./MarketConfiguration.sol";
import "../interfaces/IPool.sol";
// todo: for now can import core workspace
import "@voltz-protocol/core/src/storage/Account.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, UNIT } from "@prb/math/SD59x18.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library Portfolio {
    using Portfolio for Portfolio.Data;
    using SafeCastPrbMath for UD60x18;
    using SafeCastPrbMath for SD59x18;
    using Position for Position.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU256 for uint256;
    using RateOracleReader for RateOracleReader.Data;

    /**
     * @notice Emitted when attempting to settle before maturity
     */
    error SettlementBeforeMaturity(uint128 marketId, uint32 maturityTimestamp, uint256 accountId);
    error UnknownMarket(uint128 marketId);

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

    /**
     * @dev Creates a portfolio for a given id, the id of the portfolio and the account that owns it are the same
     */
    function create(uint128 id) internal returns (Data storage portfolio) {
        portfolio = load(id);
        // note, the portfolio id is the same as the account id that owns this portfolio
        portfolio.accountId = id;
    }

    /**
     * @dev note: given that all the accounts are single-token, unrealizedPnL for a given account is in terms
     * of the settlement token of that account
     * consider avoiding pool if account is purely taker to save gas?
     * todo: this function looks expesive and feels like there's room for optimisations
     */
    function getAccountUnrealizedPnL(Data storage self, address poolAddress, address collateralType) internal view returns (int256 unrealizedPnL) {
        // TODO: looks expensive - need to place limits on number of allowed markets and allowed maturities?
        for (uint256 i = 0; i < self.activeMarketsAndMaturities[collateralType].length(); i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities[collateralType].valueAt(i + 1);
            (uint128 marketId, uint32 maturityTimestamp) = Pack.unpack(marketMaturityPacked);

            int256 baseBalance = self.positions[marketId][maturityTimestamp].baseBalance;
            int256 quoteBalance = self.positions[marketId][maturityTimestamp].quoteBalance;

            (int256 baseBalancePool, int256 quoteBalancePool) =
                IPool(poolAddress).getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);

            int256 unwindQuote = computeUnwindQuote(marketId, maturityTimestamp, poolAddress, baseBalance + baseBalancePool);

            unrealizedPnL += unwindQuote + quoteBalance + quoteBalancePool;
        }
    }

    function computeUnwindQuote(uint128 marketId, uint32 maturityTimestamp, address poolAddress, int256 baseAmount) internal view returns (int256 unwindQuote) {
        UD60x18 timeDeltaAnnualized = Time.timeDeltaAnnualized(maturityTimestamp);

        UD60x18 currentLiquidityIndex = RateOracleReader.load(marketId).getRateIndexCurrent(maturityTimestamp);

        UD60x18 gwap = IPool(poolAddress).getDatedIRSGwap(marketId, maturityTimestamp);

        unwindQuote = SD59x18.unwrap(
            SD59x18.wrap(baseAmount)
            .mul(currentLiquidityIndex.toSD59x18())
            .mul(
                gwap.toSD59x18()
                .mul(timeDeltaAnnualized.toSD59x18())
                .add(UNIT)
            ));
    }

    /**
     * @dev in context of interest rate swaps, base refers to scaled variable tokens (e.g. scaled virtual aUSDC)
     * @dev in order to derive the annualized exposure of base tokens in quote terms (i.e. USDC), we need to
     * first calculate the (non-annualized) exposure by multiplying the baseAmount by the current liquidity index of the
     * underlying rate oracle (e.g. aUSDC lend rate oracle)
     */
    function annualizedExposureFactor(uint128 marketId, uint32 maturityTimestamp) internal view returns (UD60x18 factor) {
        // TODO: use PRB math
        UD60x18 currentLiquidityIndex = RateOracleReader.load(marketId).getRateIndexCurrent(maturityTimestamp);
        UD60x18 timeDeltaAnnualized = Time.timeDeltaAnnualized(maturityTimestamp);
        factor = currentLiquidityIndex.mul(timeDeltaAnnualized);
    }

    function baseToAnnualizedExposure(int256[] memory baseAmounts, uint128 marketId, uint32 maturityTimestamp) internal view returns (int256[] memory exposures) {
        UD60x18 factor = annualizedExposureFactor(marketId, maturityTimestamp);

        for (uint256 i = 0; i < baseAmounts.length; i++) {
            exposures[i] = SD59x18.unwrap(SD59x18.wrap(baseAmounts[i]).mul(factor.toSD59x18()));
        }
    }

    /**
     * @dev note: given that all the accounts are single-token, annualized exposures for a given account are in terms
     * of the settlement token of that account
     */
    function getAccountAnnualizedExposures(
        Data storage self,
        address poolAddress,
        address collateralType
    )
        internal
        view
        returns (Account.Exposure[] memory exposures)
    {
        uint256 marketsAndMaturitiesCount = self.activeMarketsAndMaturities[collateralType].length();
        exposures = new Account.Exposure[](marketsAndMaturitiesCount);

        for (uint256 i = 0; i < marketsAndMaturitiesCount; i++) {
            (uint128 marketId, uint32 maturityTimestamp) = self.getMarketAndMaturity(i+1, collateralType);

            int256 baseBalance = self.positions[marketId][maturityTimestamp].baseBalance;
            (int256 baseBalancePool,) = IPool(poolAddress).getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);
            (int256 unfilledBaseLong, int256 unfilledBaseShort) =
                IPool(poolAddress).getAccountUnfilledBases(marketId, maturityTimestamp, self.accountId);
            {
                UD60x18 annualizedExposureFactor = annualizedExposureFactor(marketId, maturityTimestamp);
                exposures[i] = Account.Exposure({
                    marketId: marketId,
                    filled: SD59x18.unwrap(SD59x18.wrap(baseBalance + baseBalancePool).mul(annualizedExposureFactor.toSD59x18())),
                    unfilledLong: SD59x18.unwrap(SD59x18.wrap(unfilledBaseLong).mul(annualizedExposureFactor.toSD59x18())),
                    unfilledShort: SD59x18.unwrap(SD59x18.wrap(unfilledBaseShort).mul(annualizedExposureFactor.toSD59x18()))
                });
            }
        }

        return exposures;
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

            (int256 executedBaseAmount, int256 executedQuoteAmount) = pool.executeDatedTakerOrder(marketId, maturityTimestamp, -position.baseBalance);
            position.update(executedBaseAmount, executedQuoteAmount);

            pool.closePosition(marketId, maturityTimestamp, self.accountId);

            if (position.baseBalance == 0 && position.quoteBalance == 0) {
                self.deactivateMarketMaturity(marketId, maturityTimestamp);
            }
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
        position.update(baseDelta, quoteDelta);

        // register active market
        if (position.baseBalance != 0 || position.quoteBalance != 0) {
            self.activateMarketMaturity(marketId, maturityTimestamp);
        }
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function settle(Data storage self, uint128 marketId, uint32 maturityTimestamp, address poolAddress) internal returns (int256 settlementCashflow) {
        if ( maturityTimestamp > Time.blockTimestampTruncated()) {
            revert SettlementBeforeMaturity(marketId, maturityTimestamp, self.accountId);
        }

        Position.Data storage position = self.positions[marketId][maturityTimestamp];

        // TODO: use PRB math
        UD60x18 liquidityIndexMaturity = RateOracleReader.load(marketId).getRateIndexMaturity(maturityTimestamp);

        self.deactivateMarketMaturity(marketId, maturityTimestamp);

        // todo: do we need to pass pool address?
        IPool pool = IPool(poolAddress);

        (int256 closedBasePool, int256 closedQuotePool) = pool.closePosition(marketId, maturityTimestamp, self.accountId);
        
        settlementCashflow = SD59x18.unwrap(
                SD59x18.wrap(position.baseBalance + closedBasePool)
                .mul(liquidityIndexMaturity.toSD59x18())
            )
            + position.quoteBalance + closedQuotePool;
            
        position.settle();
    }

    /**
     * @dev set market and maturity as active
     * note this can also be called by the pool when a position is intitalised
     */
    function activateMarketMaturity(Data storage self, uint128 marketId, uint32 maturityTimestamp) internal {
        // todo: check if market/maturity exist
        address collateralType = MarketConfiguration.load(marketId).quoteToken;
        if (collateralType == address(0)) {
            revert UnknownMarket(marketId);
        }
        uint256 marketMaturityPacked = Pack.pack(marketId, maturityTimestamp);
        if (!self.activeMarketsAndMaturities[collateralType].contains(marketMaturityPacked)) {
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

    // todo: add to library

    function getMarketAndMaturity(Data storage self, uint256 index, address collateralType) internal view returns (uint128 marketId, uint32 maturityTimestamp) {
        uint256 marketMaturityPacked = self.activeMarketsAndMaturities[collateralType].valueAt(index);
        (marketId, maturityTimestamp) = Pack.unpack(marketMaturityPacked);
    }
}

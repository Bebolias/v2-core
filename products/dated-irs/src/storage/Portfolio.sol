// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "./Position.sol";
import "./RateOracleReader.sol";
import "./PoolConfiguration.sol";
import "../interfaces/IPool.sol";
// todo: for now can import core workspace
import "@voltz-protocol/core/src/storage/Account.sol";
import { UD60x18, unwrap as uUnwrap } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18, UNIT, ZERO } from "@prb/math/SD59x18.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library Portfolio {
    using Portfolio for Portfolio.Data;
    using { uUnwrap } for UD60x18;
    using { toSD59x18 } for int256;
    using Position for Position.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU256 for uint256;
    using RateOracleReader for RateOracleReader.Data;

    /**
     * @notice Emitted when attempting to settle before maturity
     */
    error SettlementBeforeMaturity(uint128 marketId, uint32 maturityTimestamp, uint256 accountId);

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
        mapping(uint128 => mapping(uint256 => Position.Data)) positions;
        /**
         * @dev Maturities & ids of all the markets in which the account has active positions
         * array of marketId (e.g. aUSDC lend) and activeMaturities (e.g. 31st Dec 2023)
         */
        SetUtil.UintSet activeMarketsAndMaturities;
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
    function getAccountUnrealizedPnL(Data storage self, address poolAddress) internal view returns (SD59x18 unrealizedPnL) {
        // TODO: looks expensive - need to place limits on number of allowed markets and allowed maturities?
        for (uint256 i = 0; i < self.activeMarketsAndMaturities.length(); i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities.valueAt(i + 1);
            (uint128 marketId, uint32 maturityTimestamp) = unpack(marketMaturityPacked);

            SD59x18 baseBalance = self.positions[marketId][maturityTimestamp].baseBalance;
            SD59x18 quoteBalance = self.positions[marketId][maturityTimestamp].quoteBalance;

            (SD59x18 baseBalancePool, SD59x18 quoteBalancePool) =
                IPool(poolAddress).getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);

            uint256 timeDeltaAnnualized = Time.timeDeltaAnnualizedWad(maturityTimestamp);

            SD59x18 currentLiquidityIndex = RateOracleReader.load(marketId).getRateIndexCurrent(maturityTimestamp).uUnwrap().toInt().toSD59x18();

            uint256 gwap = IPool(poolAddress).getDatedIRSGwap(marketId, maturityTimestamp).uUnwrap();

            SD59x18 unwindQuote = baseBalance
                .add(baseBalancePool)
                .mul(currentLiquidityIndex)
                .mul(
                    SD59x18.wrap(gwap.toInt())
                    .mul(SD59x18.wrap(timeDeltaAnnualized.toInt()))
                    .add(UNIT)
                );

            unrealizedPnL = unrealizedPnL.add(unwindQuote).add(quoteBalance).add(quoteBalancePool);
        }
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
        uint256 timeDeltaAnnualized = Time.timeDeltaAnnualizedWad(maturityTimestamp);

        factor = currentLiquidityIndex.mul(UD60x18.wrap(timeDeltaAnnualized));
    }

    function baseToAnnualizedExposure(SD59x18[] memory baseAmounts, uint128 marketId, uint32 maturityTimestamp) internal view returns (SD59x18[] memory exposures) {
        UD60x18 factor = annualizedExposureFactor(marketId, maturityTimestamp);

        for (uint256 i = 0; i < baseAmounts.length; i++) {
            exposures[i] = baseAmounts[i].mul(SD59x18.wrap(factor.uUnwrap().toInt()));
        }
    }

    /**
     * @dev note: given that all the accounts are single-token, annualized exposures for a given account are in terms
     * of the settlement token of that account
     */
    function getAccountAnnualizedExposures(
        Data storage self,
        address poolAddress
    )
        internal
        view
        returns (Account.Exposure[] memory exposures)
    {
        uint256 marketsAndMaturitiesCount = self.activeMarketsAndMaturities.length();
        exposures = new Account.Exposure[](marketsAndMaturitiesCount);

        for (uint256 i = 0; i < marketsAndMaturitiesCount; i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities.valueAt(i + 1);
            (uint128 marketId, uint32 maturityTimestamp) = unpack(marketMaturityPacked);

            SD59x18 baseBalance = self.positions[marketId][maturityTimestamp].baseBalance;
            (SD59x18 baseBalancePool,) = IPool(poolAddress).getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);
            (SD59x18 unfilledBaseLong, SD59x18 unfilledBaseShort) =
                IPool(poolAddress).getAccountUnfilledBases(marketId, maturityTimestamp, self.accountId);
            {
                UD60x18 annualizedExposureFactor = annualizedExposureFactor(marketId, maturityTimestamp);

                exposures[i] = Account.Exposure({
                    marketId: marketId,
                    filled: baseBalance.add(baseBalancePool).mul(SD59x18.wrap(annualizedExposureFactor.uUnwrap().toInt())),
                    unfilledLong: unfilledBaseLong.mul(SD59x18.wrap(annualizedExposureFactor.uUnwrap().toInt())),
                    unfilledShort: unfilledBaseShort.mul(SD59x18.wrap(annualizedExposureFactor.uUnwrap().toInt()))
                });
            }
        }

        return exposures;
    }

    /**
     * @dev Fully Close all the positions owned by the account within the dated irs portfolio
     * poolAddress in which to close the account, note in the beginning we'll only have a single pool
     */
    function closeAccount(Data storage self, address poolAddress) internal {
        IPool pool = IPool(poolAddress);
        for (uint256 i = 1; i <= self.activeMarketsAndMaturities.length(); i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities.valueAt(i);
            (uint128 marketId, uint32 maturityTimestamp) = unpack(marketMaturityPacked);

            Position.Data storage position = self.positions[marketId][maturityTimestamp];

            (SD59x18 executedBaseAmount, SD59x18 executedQuoteAmount) = pool.executeDatedTakerOrder(marketId, maturityTimestamp, ZERO.sub(position.baseBalance));
            position.update(executedBaseAmount, executedQuoteAmount);

            pool.closePosition(marketId, maturityTimestamp, self.accountId);

            if (position.baseBalance.eq(ZERO) && position.quoteBalance.eq(ZERO)) {
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
        SD59x18 baseDelta,
        SD59x18 quoteDelta
    )
        internal
    {
        Position.Data storage position = self.positions[marketId][maturityTimestamp];
        position.update(baseDelta, quoteDelta);

        // register active market
        if (position.baseBalance.neq(ZERO) || position.quoteBalance.neq(ZERO)) {
            self.activateMarketMaturity(marketId, maturityTimestamp);
        }
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function settle(Data storage self, uint128 marketId, uint32 maturityTimestamp) internal returns (SD59x18 settlementCashflow) {
        if ( maturityTimestamp < uint32(block.timestamp)) {
            revert SettlementBeforeMaturity(marketId, maturityTimestamp, self.accountId);
        }

        Position.Data storage position = self.positions[marketId][maturityTimestamp];

        // TODO: use PRB math
        UD60x18 liquidityIndexMaturity = RateOracleReader.load(marketId).getRateIndexMaturity(maturityTimestamp);

        self.deactivateMarketMaturity(marketId, maturityTimestamp);

        // todo: replace pool configuration
        address _poolAddress = PoolConfiguration.getPoolAddress();
        IPool pool = IPool(_poolAddress);

        (SD59x18 closedBasePool, SD59x18 closedQuotePool) = pool.closePosition(marketId, maturityTimestamp, self.accountId);
        position.settle();
        
        settlementCashflow = position.baseBalance
            .add(closedBasePool)
            .mul(liquidityIndexMaturity.uUnwrap().toInt().toSD59x18())
            .add(position.quoteBalance)
            .add(closedQuotePool);
    }

    /**
     * @dev set market and maturity as active
     * note this can also be called by the pool when a position is intitalised
     */
    function activateMarketMaturity(Data storage self, uint128 marketId, uint32 maturityTimestamp) internal {
        // todo: check if market/maturity exist
        uint256 marketMaturityPacked = pack(marketId, maturityTimestamp);
        if (!self.activeMarketsAndMaturities.contains(marketMaturityPacked)) {
            self.activeMarketsAndMaturities.add(marketMaturityPacked);
        }
    }

    /**
     * @dev set market and maturity as inactive
     * note this can also be called by the pool when a position is settled
     */
    function deactivateMarketMaturity(Data storage self, uint128 marketId, uint32 maturityTimestamp) internal {
        uint256 marketMaturityPacked = pack(marketId, maturityTimestamp);
        if (self.activeMarketsAndMaturities.contains(marketMaturityPacked)) {
            self.activeMarketsAndMaturities.remove(marketMaturityPacked);
        }
    }

    // todo: add to library
    function pack(uint128 a, uint32 b) internal pure returns (uint256) {
        return (a << 32) | b;
    }

    function unpack(uint256 value) internal view returns (uint128 a, uint32 b) {
        a = uint128(value >> 32);
        b = uint32(value - uint256(a << 32)); // todo: safecast
    }
}

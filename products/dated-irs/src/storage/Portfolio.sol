// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "@voltz-protocol/core/src/utils/contracts/helpers/SetUtil.sol";
import "@voltz-protocol/core/src/utils/contracts/helpers/SafeCast.sol";
import "./Position.sol";
import "./RateOracleReader.sol";
import "./PoolConfiguration.sol";
import "../interfaces/IPool.sol";
// todo: for now can import core workspace
import "@voltz-protocol/core/src/storage/Account.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library Portfolio {
    using { unwrap } for UD60x18;
    using Position for Position.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU256 for uint256;
    using RateOracleReader for RateOracleReader.Data;

    // todo: do we need pool configuration here? currently only holding address
    using PoolConfiguration for PoolConfiguration.Data;

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
    function getAccountUnrealizedPnL(Data storage self, address poolAddress)
        internal
        view
        returns (int256 unrealizedPnL)
    {
        // TODO: looks expensive - need to place limits on number of allowed markets and allowed maturities?
        for (uint256 i = 0; i < self.activeMarketsAndMaturities.length(); i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities.valueAt(i + 1);
            ( uint128 marketId, uint32 maturityTimestamp ) = unpack(marketMaturityPacked);

            int256 baseBalance = self.positions[marketId][maturityTimestamp].baseBalance;
            int256 quoteBalance = self.positions[marketId][maturityTimestamp].quoteBalance;

            (int256 baseBalancePool, int256 quoteBalancePool) =
                IPool(poolAddress).getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);

            int256 timeDeltaAnnualizedWad = max(0, ((maturityTimestamp - block.timestamp) * 1e18 / 31540000).toInt());

            // TODO: use PRB math
            int256 currentLiquidityIndex =
                RateOracleReader.load(marketId).getRateIndexCurrent(maturityTimestamp).unwrap().toInt();

            int256 gwap =
                IPool(poolAddress).getDatedIRSGwap(marketId, maturityTimestamp).toInt();

            int256 unwindQuote =
                (baseBalance + baseBalancePool) * 
                ( (currentLiquidityIndex * (gwap * timeDeltaAnnualizedWad / 1e18 + 1e18)) /1e18 )
                / 1e18;
            unrealizedPnL += (unwindQuote + quoteBalance + quoteBalancePool);
        }
    }

    /**
     * @dev in context of interest rate swaps, base refers to scaled variable tokens (e.g. scaled virtual aUSDC)
     * @dev in order to derive the annualized exposure of base tokens in quote terms (i.e. USDC), we need to
     * first calculate the (non-annualized) exposure by multiplying the baseAmount by the current liquidity index of the
     * underlying rate oracle (e.g. aUSDC lend rate oracle)
     */
    function annualizedExposureFactor(uint128 marketId, uint32 maturityTimestamp)
        internal
        view
        returns (int256 factor)
    {
        // TODO: use PRB math
        int256 currentLiquidityIndex =
            RateOracleReader.load(marketId).getRateIndexCurrent(maturityTimestamp).unwrap().toInt();
        int256 timeDelta = int32(maturityTimestamp) - int32(uint32(block.timestamp));
        int256 timeDeltaAnnualizedWad = max(0, (timeDelta * 1e18 / 31540000));

        factor = currentLiquidityIndex * timeDeltaAnnualizedWad / 1e18;
    }

    /**
     * @dev note: given that all the accounts are single-token, annualized exposures for a given account are in terms
     * of the settlement token of that account
     */
    function getAccountAnnualizedExposures(Data storage self, address poolAddress)
        internal
        view
        returns (Account.Exposure[] memory exposures)
    {
        uint256 marketsAndMaturitiesCount = self.activeMarketsAndMaturities.length();
        exposures = new Account.Exposure[](marketsAndMaturitiesCount);

        for (uint256 i = 0; i < marketsAndMaturitiesCount; i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities.valueAt(i + 1);
            ( uint128 marketId, uint32 maturityTimestamp ) = unpack(marketMaturityPacked);

            int256 baseBalance = self.positions[marketId][maturityTimestamp].baseBalance;
            (int256 baseBalancePool,) =
                IPool(poolAddress).getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);
            (int256 unfilledBaseLong, int256 unfilledBaseShort) =
                IPool(poolAddress).getAccountUnfilledBases(marketId, maturityTimestamp, self.accountId);
            {
                int256 annualizedExposureFactor = 
                    annualizedExposureFactor(marketId, maturityTimestamp);

                exposures[i] = Account.Exposure({
                    marketId: marketId,
                    filled: (baseBalance + baseBalancePool) * annualizedExposureFactor,
                    unfilledLong: unfilledBaseLong * annualizedExposureFactor,
                    unfilledShort: unfilledBaseShort * annualizedExposureFactor
                });
            }
        }

        return exposures;
    }

    /**
     * @dev Fully Close all the positions owned by the account within the dated irs portfolio
     * poolAddress in which to close the account, note in the beginning we'll only have a single pool
     * todo: layer in position closing in the pool
     * todo: pool.executeDatedTakerOrder(marketId, maturityTimestamp, -position.baseBalance); -> consider passing a list of
     * structs such that there is only a single external call done to the poolAddress?
     */
    function closeAccount(Data storage self, address poolAddress) internal {
        IPool pool = IPool(poolAddress);
        for (uint256 i = 1; i <= self.activeMarketsAndMaturities.length(); i++) {
            uint256 marketMaturityPacked = self.activeMarketsAndMaturities.valueAt(i);
            ( uint128 marketId, uint32 maturityTimestamp ) = unpack(marketMaturityPacked);

            Position.Data memory position = self.positions[marketId][maturityTimestamp];
            pool.executeDatedTakerOrder(marketId, maturityTimestamp, -position.baseBalance);
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
    ) internal {
        Position.Data storage position = self.positions[marketId][maturityTimestamp];
        position.update(baseDelta, quoteDelta);

        // register active market
        if (position.baseBalance != 0  || position.quoteBalance != 0) {
            activatePool(self, marketId, maturityTimestamp);
        }
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function settle(Data storage self, uint128 marketId, uint32 maturityTimestamp)
        internal
        returns (int256 settlementCashflow)
    {
        // todo: check for maturity? RateOracleReader would fail if not matured

        Position.Data storage position = self.positions[marketId][maturityTimestamp];

        // TODO: use PRB math
        int256 liquidityIndexMaturity =
            RateOracleReader.load(marketId).getRateIndexMaturity(maturityTimestamp).unwrap().toInt();

        settlementCashflow = position.baseBalance * liquidityIndexMaturity + position.quoteBalance;
        position.settle();
    }

    /**
     * @dev set market and maturity as active
     * note this can also be called by the pool when a position is intitalised
     */
    function activatePool(
        Data storage self,
        uint128 marketId,
        uint32 maturityTimestamp
    ) internal {
        // todo: check if market/maturity exist
        uint256 marketMaturityPacked = pack(marketId, maturityTimestamp);
        if(!self.activeMarketsAndMaturities.contains(
            marketMaturityPacked
        )) {
            self.activeMarketsAndMaturities.add(marketMaturityPacked);
        }
    }

    /**
     * @dev set market and maturity as inactive
     * note this can also be called by the pool when a position is settled
     */
    function deactivatePool(
        Data storage self,
        uint128 marketId,
        uint32 maturityTimestamp
    ) internal {
        uint256 marketMaturityPacked = pack(marketId, maturityTimestamp);
        if(self.activeMarketsAndMaturities.contains(
            marketMaturityPacked
        )) {
            self.activeMarketsAndMaturities.remove(marketMaturityPacked);
        }
    }

    // todo: consider replacing with prb math
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    // todo: add to library
    function pack(uint128 a, uint32 b) internal pure returns (uint256) {
        return ( a << 32 ) | b;
    }

    function unpack(uint256 value) internal view returns (uint128 a, uint32 b) {
        a = uint128(value >> 32);
        b = uint32(value - uint256(a << 32)); // todo: safecast
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/helpers/SetUtil.sol";
import "../../utils/helpers/SafeCast.sol";
import "./DatedIRSPosition.sol";
import "./RateOracleManagerStorage.sol";
import "../interfaces/IRateOracleManager.sol";
import "../interfaces/IPool.sol";
// todo: consider migrating Exposures from Account.sol to more relevant place (e.g. interface)
import "../../accounts/storage/Account.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library DatedIRSPortfolio {
    using DatedIRSPosition for DatedIRSPosition.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU256 for uint256;

    struct Data {
        /**
         * @dev Numeric identifier for the account that owns the portfolio.
         * @dev Since a given account can only own a single portfolio in a given dated product
         * the id of the portfolio is the same as the id of the account
         * @dev There cannot be an account and hence dated portfolio with id zero
         */
        uint128 accountId;
        /**
         * @dev marketId (e.g. aUSDC lend) --> maturityTimestamp (e.g. 31st Dec 2023) --> DatedIRSPosition object with filled balances
         */
        mapping(uint128 => mapping(uint256 => DatedIRSPosition.Data)) positions;
        /**
         * @dev Ids of all the markets in which the account has active positions
         * todo: needs logic to mark active markets
         * todo: consider just maintaining a single SetUtil which is a set of structs of the form (marketId, maturityTimestamp)
         * meaning the need for double for loops below disappears + the need for activeMaturitiesPerMarket + extra marking should
         * disappear as well
         */
        SetUtil.UintSet activeMarkets;
        /**
         * @dev marketId (e.g. aUSDC lend) -> activeMaturities (e.g. 31st Dec 2023)
         */
        mapping(uint128 => SetUtil.UintSet) activeMaturitiesPerMarket;
    }

    /**
     * @dev Returns the portfolio stored at the specified portfolio id
     * @dev Same as account id of the account that owns the portfolio of dated irs positions
     */
    function load(uint128 accountId) internal pure returns (Data storage portfolio) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.DatedIRSPortfolio", accountId));
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
        SetUtil.UintSet storage _activeMarkets = self.activeMarkets;
        for (uint256 i = 1; i < _activeMarkets.length(); i++) {
            uint128 marketId = _activeMarkets.valueAt(i).to128();
            SetUtil.UintSet storage _activeMaturities = self.activeMaturitiesPerMarket[marketId];
            for (uint256 j = 1; i < _activeMaturities.length(); i++) {
                uint256 maturityTimestamp = _activeMaturities.valueAt(j);
                DatedIRSPosition.Data memory position = self.positions[marketId][maturityTimestamp];

                IPool pool = IPool(poolAddress);

                (int256 baseBalancePool, int256 quoteBalancePool) =
                    pool.getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);

                int256 timeDeltaAnnualized = max(0, ((maturityTimestamp - block.timestamp) / 31540000).toInt());

                RateOracleManagerStorage.Data memory oracleManager = RateOracleManagerStorage.load();
                int256 currentLiquidityIndex =
                    IRateOracleManager(oracleManager.oracleManagerAddress).getRateIndexCurrent(marketId).toInt();

                int256 gwap = IRateOracleManager(oracleManager.oracleManagerAddress).getDatedIRSGwap(
                    marketId, maturityTimestamp
                ).toInt();

                int256 unwindQuote =
                    (position.baseBalance + baseBalancePool) * currentLiquidityIndex * (gwap * timeDeltaAnnualized + 1);
                unrealizedPnL += (unwindQuote + position.quoteBalance + quoteBalancePool);
            }
        }
    }

    /**
     * @dev in context of interest rate swaps, base refers to scaled variable tokens (e.g. scaled virtual aUSDC)
     * @dev in order to derive the annualized exposure of base tokens in quote terms (i.e. USDC), we need to
     * first calculate the (non-annualized) exposure by multiplying the baseAmount by the current liquidity index of the
     * underlying rate oracle (e.g. aUSDC lend rate oracle)
     */
    function baseToAnnualizedExposure(int256 baseAmount, uint128 marketId, uint256 maturityTimestamp)
        internal
        view
        returns (int256 exposure)
    {
        RateOracleManagerStorage.Data memory oracleManager = RateOracleManagerStorage.load();
        int256 currentLiquidityIndex =
            IRateOracleManager(oracleManager.oracleManagerAddress).getRateIndexCurrent(marketId).toInt();
        int256 timeDeltaAnnualized = max(0, ((maturityTimestamp - block.timestamp) / 31540000).toInt());
        exposure = baseAmount * currentLiquidityIndex * timeDeltaAnnualized;
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
        SetUtil.UintSet storage _activeMarkets = self.activeMarkets;
        uint256 counter = 0;
        for (uint256 i = 1; i < _activeMarkets.length(); i++) {
            uint128 marketId = _activeMarkets.valueAt(i).to128();
            SetUtil.UintSet storage _activeMaturities = self.activeMaturitiesPerMarket[marketId];
            for (uint256 j = 1; i < _activeMaturities.length(); j++) {
                uint256 maturityTimestamp = _activeMaturities.valueAt(j);
                DatedIRSPosition.Data memory position = self.positions[marketId][maturityTimestamp];

                IPool pool = IPool(poolAddress);

                (int256 baseBalancePool,) = pool.getAccountFilledBalances(marketId, maturityTimestamp, self.accountId);
                (int256 unfilledBaseLong, int256 unfilledBaseShort) =
                    pool.getAccountUnfilledBases(marketId, maturityTimestamp, self.accountId);

                exposures[counter] = Account.Exposure({
                    marketId: marketId,
                    filled: baseToAnnualizedExposure((position.baseBalance + baseBalancePool), marketId, maturityTimestamp),
                    unfilledLong: baseToAnnualizedExposure(unfilledBaseLong, marketId, maturityTimestamp),
                    unfilledShort: baseToAnnualizedExposure(unfilledBaseShort, marketId, maturityTimestamp)
                });
                counter++;
            }
        }
    }

    /**
     * @dev Fully Close all the positions owned by the account within the dated irs portfolio
     * poolAddress in which to close the account, note in the beginning we'll only have a single pool
     * todo: layer in position closing in the pool
     * todo: pool.executeDatedTakerOrder(marketId, maturityTimestamp, -position.baseBalance); -> consider passing a list of
     * structs such that there is only a single external call done to the poolAddress?
     */
    function closeAccount(Data storage self, address poolAddress) internal {
        SetUtil.UintSet storage _activeMarkets = self.activeMarkets;
        IPool pool = IPool(poolAddress);
        for (uint256 i = 1; i < _activeMarkets.length(); i++) {
            uint128 marketId = _activeMarkets.valueAt(i).to128();
            SetUtil.UintSet storage _activeMaturities = self.activeMaturitiesPerMarket[marketId];
            for (uint256 j = 1; i < _activeMaturities.length(); j++) {
                uint256 maturityTimestamp = _activeMaturities.valueAt(j);

                DatedIRSPosition.Data memory position = self.positions[marketId][maturityTimestamp];
                pool.executeDatedTakerOrder(marketId, maturityTimestamp, -position.baseBalance);
            }
        }
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function updatePosition(
        Data storage self,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseDelta,
        int256 quoteDelta
    ) internal {
        DatedIRSPosition.Data storage position = self.positions[marketId][maturityTimestamp];
        position.update(baseDelta, quoteDelta);
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function settle(Data storage self, uint128 marketId, uint256 maturityTimestamp)
        internal
        returns (int256 settlementCashflow)
    {
        DatedIRSPosition.Data storage position = self.positions[marketId][maturityTimestamp];

        RateOracleManagerStorage.Data memory oracleManager = RateOracleManagerStorage.load();
        int256 liquidityIndexMaturity = IRateOracleManager(oracleManager.oracleManagerAddress).getRateIndexAtMaturity(
            marketId, maturityTimestamp
        ).toInt();

        settlementCashflow = position.baseBalance * liquidityIndexMaturity + position.quoteBalance;
        position.settle();
    }

    // todo: consider replacing with prb math
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }
}

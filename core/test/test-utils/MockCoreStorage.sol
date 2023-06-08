// https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
pragma solidity >=0.8.19;

import "./MockAccountStorage.sol";
import "./MockProductStorage.sol";
import "./MockProduct.sol";
import "./Constants.sol";
import "../../src/storage/MarketRiskConfiguration.sol";
import "../../src/storage/CollateralConfiguration.sol";
import "../../src/storage/MarketFeeConfiguration.sol";
import "../../src/storage/Periphery.sol";
import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";

import {UD60x18} from "@prb/math/UD60x18.sol";
import {SD59x18} from "@prb/math/SD59x18.sol";

contract MockCoreStorage is MockAccountStorage, MockProductStorage {}

/**
 * @dev Core storage mocks for accounts and products
 * @dev Products:
 *        - - id: 1
 *          - product address: PRODUCT_ADDRESS_1
 *          - name: "Product 1"
 *          - owner: PRODUCT_OWNER
 *
 *        - - id: 2
 *          - product address: PRODUCT_ADDRESS_2
 *          - name: "Product 2"
 *          - owner: PRODUCT_OWNER
 * @dev Collaterals:
 *        - - TOKEN_0
 *          - liquidation booster: 10
 *          - CAP: 100000
 *        - - TOKEN_1
 *          - liquidation booster: 0.4
 *          - cap: 1000
 * @dev Market risk configurations:
 *        - - productId: 1
 *          - marketId: 10
 *          - settlementToken: TOKEN_0
 *          - riskParameter: 1
 *
 *        - - productId: 1
 *          - marketId: 11
 *          - settlementToken: TOKEN_0
 *          - riskParameter: 1
 *
 *        - - productId: 2
 *          - marketId: 20
 *          - settlementToken: TOKEN_0
 *          - riskParameter: 1
 *
 *        // todo: test single account single-token mode
 *        - - productId: 2
 *          - marketId: 21
 *          - settlementToken: TOKEN_1
 *          - riskParameter: 1
 * @dev Accounts:
 *        - Alice:
 *          - id: 100
 *          - owner: ALICE
 *          - default balances: (TOKEN_0, 10000), (TOKEN_1, 10)
 *          - product IDs: 1, 2
 *
 *          - mocked exposures:
 *            - (productId: 1, marketId: 10):
 *              - filled: 100
 *              - unfilled long: 200
 *              - unfilled short: -200
 *
 *            - (productId: 1, marketId: 11):
 *              - filled: 200
 *              - unfilled long: 300
 *              - unfilled short: -400
 *
 *            - (productId: 2, marketId: 20):
 *              - filled: -50
 *              - unfilled long: 150
 *              - unfilled short: -150
 *
 *            - (productId: 2, marketId: 21):
 *              - filled: -5
 *              - unfilled long: 0
 *              - unfilled short: 0
 *
 *          - margin requirements:
 *              - TOKEN_0: (im, 1800), (lm, 900)
 *              - TOKEN_0: (im, 3), (lm, 1)
 *
 *          - mocked uPnLs:
 *            - (productId: 1, token: TOKEN_0) : 100
 *            - (productId: 2, token: TOKEN_0) : -200
 *            - (productId: 2, token: TOKEN_1) : 0.1
 * @dev Protocol risk configurations:
 *        - im multiplier: 2
 *        - liquidator reward: 0.05
 * @dev Protocol Fee configurations:
 *        - (productId: 1, marketId: 10):
 *          - feeCollectorAccountId: 999
 *          - atomicMakerFee: 0.01
 *          - atomicTakerFee: 0.05
 *
 *        - (productId: 1, marketId: 11):
 *          - feeCollectorAccountId: 999
 *          - atomicMakerFee: 0.02
 *          - atomicTakerFee: 0.04
 *
 *        - (productId: 2, marketId: 20):
 *          - feeCollectorAccountId: 999
 *          - atomicMakerFee: 0.04
 *          - atomicTakerFee: 0.02
 *
 *        - (productId: 2, marketId: 21):
 *          - feeCollectorAccountId: 999
 *          - atomicMakerFee: 0.05
 *          - atomicTakerFee: 0.01
 */
contract CoreState is MockCoreStorage, Ownable {
    using SetUtil for SetUtil.AddressSet;

    MockProduct[] internal products;

    constructor() Ownable(Constants.PROXY_OWNER) {
        // Allow _CREATE_PRODUCT Feature Flag to PRODUCT_CREATOR
        SetUtil.AddressSet storage permissionedAddresses = FeatureFlag.load("registerProduct").permissionedAddresses;
        permissionedAddresses.add(Constants.PRODUCT_CREATOR);

        // Set protocol risk configuration
        ProtocolRiskConfiguration.set(
            ProtocolRiskConfiguration.Data({
                imMultiplier: UD60x18.wrap(2e18),
                liquidatorRewardParameter: UD60x18.wrap(5e16)
            })
        );

        // Mock collateral configuration (token 0)
        CollateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationBooster: Constants.TOKEN_0_LIQUIDATION_BOOSTER,
                tokenAddress: Constants.TOKEN_0,
                cap: Constants.TOKEN_0_CAP
            })
        );

        // Mock collateral configuration (token 1)
        CollateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: false,
                liquidationBooster: Constants.TOKEN_1_LIQUIDATION_BOOSTER,
                tokenAddress: Constants.TOKEN_1,
                cap: Constants.TOKEN_1_CAP
            })
        );

        // set periphery address
        Periphery.setPeriphery(Constants.PERIPHERY);

        // Create product (id: 1)
        {
            products.push(new MockProduct("Product 1"));
            uint128 productId = mockProduct(address(products[0]), "Product 1", Constants.PRODUCT_OWNER);
            require(productId == 1, "Mock Core: Unexpected Product Id (1)");
        }

        // Create product (id: 2)
        {
            products.push(new MockProduct("Product 2"));
            uint128 productId = mockProduct(address(products[1]), "Product 2", Constants.PRODUCT_OWNER);
            require(productId == 2, "Mock Core: Unexpected Product Id (2)");
        }

        // Create account (id: 100)
        {
            CollateralBalance[] memory balances = new CollateralBalance[](2);
            balances[0] = CollateralBalance({
                token: Constants.TOKEN_0,
                balance: Constants.DEFAULT_TOKEN_0_BALANCE,
                liquidationBoosterBalance: Constants.TOKEN_0_LIQUIDATION_BOOSTER
            });
            balances[1] = CollateralBalance({
                token: Constants.TOKEN_1,
                balance: Constants.DEFAULT_TOKEN_1_BALANCE,
                liquidationBoosterBalance: Constants.TOKEN_1_LIQUIDATION_BOOSTER
            });

            uint128[] memory activeProductIds = new uint128[](2);
            activeProductIds[0] = 1;
            activeProductIds[1] = 2;

            mockAccount(100, Constants.ALICE, balances, activeProductIds);
        }

        // Create account (id: 101)
        {
            CollateralBalance[] memory balances = new CollateralBalance[](2);
            balances[0] = CollateralBalance({
                token: Constants.TOKEN_0,
                balance: Constants.DEFAULT_TOKEN_0_BALANCE,
                liquidationBoosterBalance: Constants.TOKEN_0_LIQUIDATION_BOOSTER
            });
            balances[1] = CollateralBalance({
                token: Constants.TOKEN_1,
                balance: Constants.DEFAULT_TOKEN_1_BALANCE,
                liquidationBoosterBalance: Constants.TOKEN_1_LIQUIDATION_BOOSTER
            });

            uint128[] memory activeProductIds;
            mockAccount(101, Constants.BOB, balances, activeProductIds);
        }

        // Create account (id: 999)
        {
            CollateralBalance[] memory balances;
            uint128[] memory activeProductIds;
            mockAccount(999, Constants.FEES_COLLECTOR, balances, activeProductIds);
        }

        // Mock Calls to Product Smart Contracts regarding Alice account
        mockAliceCalls();

        // Set market risk configuration
        MarketRiskConfiguration.set(
            MarketRiskConfiguration.Data({productId: 1, marketId: 10, riskParameter: SD59x18.wrap(1e18), twapLookbackWindow: 86400})
        );
        MarketRiskConfiguration.set(
            MarketRiskConfiguration.Data({productId: 1, marketId: 11, riskParameter: SD59x18.wrap(1e18), twapLookbackWindow: 86400})
        );
        MarketRiskConfiguration.set(
            MarketRiskConfiguration.Data({productId: 2, marketId: 20, riskParameter: SD59x18.wrap(1e18), twapLookbackWindow: 86400})
        );

        // Set market fee configuration
        MarketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 10,
                feeCollectorAccountId: 999,
                atomicMakerFee: UD60x18.wrap(1e16),
                atomicTakerFee: UD60x18.wrap(5e16)
            })
        );
        MarketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 1,
                marketId: 11,
                feeCollectorAccountId: 999,
                atomicMakerFee: UD60x18.wrap(2e16),
                atomicTakerFee: UD60x18.wrap(4e16)
            })
        );
        MarketFeeConfiguration.set(
            MarketFeeConfiguration.Data({
                productId: 2,
                marketId: 20,
                feeCollectorAccountId: 999,
                atomicMakerFee: UD60x18.wrap(4e16),
                atomicTakerFee: UD60x18.wrap(2e16)
            })
        );

        // todo: test single account single-token mode
        // Set market risk configuration
        // MarketRiskConfiguration.set(MarketRiskConfiguration.Data({productId: 2, marketId: 21, riskParameter: 1e18}));
    }

    function getProducts() external view returns (MockProduct[] memory) {
        return products;
    }

    function mockAliceCalls() internal {
        // Mock account (id:100) exposures to product (id:1) and markets (ids: 10, 11) (TOKEN_0)
        {
            Account.Exposure[] memory mockExposures = new Account.Exposure[](2);

            mockExposures[0] =
                Account.Exposure({marketId: 10, filled: 100e18, unfilledLong: 200e18, unfilledShort: 200e18});
            mockExposures[1] =
                Account.Exposure({marketId: 11, filled: 200e18, unfilledLong: 300e18, unfilledShort: 400e18});

            products[0].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_0, mockExposures);

            Account.Exposure[] memory emptyExposures;
            products[0].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_1, emptyExposures);
            products[0].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_UNKNOWN, emptyExposures);

            products[0].mockBaseToAnnualizedExposure(10, 123000, 5e17);
            products[0].mockBaseToAnnualizedExposure(11, 120000, 25e16);
        }
        // Mock account (id: 100) unrealized PnL in product (id: 1)
        products[0].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_0, 100e18);
        products[0].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_1, 0);
        products[0].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_UNKNOWN, 0);

        // Mock account (id:100) exposures to product (id:2) and markets (ids: 20) (TOKEN_0)
        {
            Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

            mockExposures[0] =
                Account.Exposure({marketId: 20, filled: -50e18, unfilledLong: 150e18, unfilledShort: 150e18});

            products[1].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_0, mockExposures);

            // todo: test single account single-token mode
            Account.Exposure[] memory emptyExposures;
            products[1].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_1, emptyExposures);
            products[1].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_UNKNOWN, emptyExposures);

            products[1].mockBaseToAnnualizedExposure(20, 145000, 2e18);
        }
        // Mock account (id: 100) unrealized PnL in product (id: 2)
        products[1].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_0, -200e18);

        // todo: test single account single-token mode
        // Mock account (id:100) exposures to product (id:2) and markets (ids: 21) (TOKEN_1)
        // {
        //     Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

        //     mockExposures[0] = Account.Exposure({marketId: 21, filled: -5e18, unfilledLong: 0, unfilledShort: 0});

        //     products[1].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_1, mockExposures);

        //     products[1].mockBaseToAnnualizedExposure(21, 155000, 3e18);
        // }
        // todo: test single account single-token mode
        // products[1].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_1, 1e17);
        products[1].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_1, 0);
        products[1].mockGetAccountUnrealizedPnL(100, Constants.TOKEN_UNKNOWN, 0);
    }
}

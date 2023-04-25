pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import "../src/oracles/AaveRateOracle.sol";
import "../src/modules/ProductIRSModule.sol";
import "../src/interfaces/IRateOracleModule.sol";
import "../src/storage/MarketConfiguration.sol";
import "@voltz-protocol/core/src/interfaces/external/IProduct.sol";
import "@voltz-protocol/core/src/modules/AccountModule.sol";
import "@voltz-protocol/core/src/storage/AccountRBAC.sol";
import "@voltz-protocol/core/src/modules/ProductModule.sol";
import "oz/interfaces/IERC20.sol";
import "./mocks/MockRateOracle.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

contract ProductIRSModuleExtended is ProductIRSModule {
    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }

    function getProductConfig() external returns (ProductConfiguration.Data memory) {
        return ProductConfiguration.load();
    }

    function createRateOracle(uint128 marketId, address oracleAddress) external returns (bytes32 s) {
        RateOracleReader.Data storage oracle = RateOracleReader.set(marketId, oracleAddress);
        assembly {
            s := oracle.slot
        }
    }

    function createMarket(uint128 marketId, address quoteToken) external {
        MarketConfiguration.set(MarketConfiguration.Data({ marketId: marketId, quoteToken: quoteToken }));
    }

    function createPortfolio(uint128 accountId) external {
        Portfolio.create(accountId);
    }
}

contract MockCoreStorage is AccountModule, ProductModule { }

contract ProductIRSModuleTest is Test {
    using ProductConfiguration for ProductConfiguration.Data;

    event ProductConfigured(ProductConfiguration.Data config);

    address constant MOCK_QUOTE_TOKEN = 0x1122334455667788990011223344556677889900;
    uint32 maturityTimestamp;
    uint128 constant MOCK_MARKET_ID = 100;
    uint128 constant MOCK_PRODUCT_ID = 123;
    address constant MOCK_USER = address(1234);
    uint128 constant MOCK_ACCOUNT_ID = 1234;

    ProductIRSModuleExtended productIrs;
    MockCoreStorage mockCoreStorage;
    MockRateOracle mockRateOracle;

    function setUp() public virtual {
        maturityTimestamp = Time.blockTimestampTruncated() + 31536000;

        productIrs = new ProductIRSModuleExtended();
        productIrs.setOwner(address(this));

        mockCoreStorage = new MockCoreStorage();

        // create Rate Oracle
        mockRateOracle = new MockRateOracle();
        mockRateOracle.setLastUpdatedIndex(1e18 * 1e9);
        productIrs.createRateOracle(MOCK_MARKET_ID, address(mockRateOracle));

        // create market
        productIrs.createMarket(MOCK_MARKET_ID, MOCK_QUOTE_TOKEN);

        // create product
        productIrs.configureProduct(
            ProductConfiguration.Data({ productId: MOCK_PRODUCT_ID, coreProxy: address(mockCoreStorage), poolAddress: address(2) })
        );
    }

    function test_ProductConfiguredCorrectly() public {
        // expect RateOracleRegistered event
        ProductConfiguration.Data memory config =
            ProductConfiguration.Data({ productId: 124, coreProxy: address(3), poolAddress: address(4) });

        vm.expectEmit(true, true, false, true);
        emit ProductConfigured(config);

        productIrs.configureProduct(config);

        ProductConfiguration.Data memory configRecived = productIrs.getProductConfig();
        assertEq(configRecived.productId, 124);
        assertEq(configRecived.coreProxy, address(3));
        assertEq(configRecived.poolAddress, address(4));
    }

    function test_SupportsInterfaceIERC165() public {
        assertTrue(productIrs.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterfaceIRateOracle() public {
        assertTrue(productIrs.supportsInterface(type(IProduct).interfaceId));
    }

    function test_SupportsOtherInterfaces() public {
        assertFalse(productIrs.supportsInterface(type(IERC20).interfaceId));
    }

    function test_RevertWhen_CloseAccount() public {
        vm.prank(address(7));
        vm.expectRevert();
        productIrs.closeAccount(178, MOCK_QUOTE_TOKEN);
    }

    function test_CloseEmptyAccount() public {
        vm.prank(address(mockCoreStorage));
        productIrs.closeAccount(178, MOCK_QUOTE_TOKEN);
    }

    function test_InitiateTakerOrder() public {
        address thisAddress = address(this);

        vm.mockCall(
            address(mockCoreStorage),
            abi.encodeWithSelector(
                IAccountModule.onlyAuthorized.selector, MOCK_ACCOUNT_ID, AccountRBAC._ADMIN_PERMISSION, MOCK_USER
            ),
            abi.encode()
        );
        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.executeDatedTakerOrder.selector, MOCK_MARKET_ID, maturityTimestamp, 100),
            abi.encode(10, -10)
        );
        vm.mockCall(
            address(mockCoreStorage),
            abi.encodeWithSelector(
                IProductModule.propagateTakerOrder.selector, MOCK_ACCOUNT_ID, MOCK_PRODUCT_ID, MOCK_MARKET_ID, MOCK_QUOTE_TOKEN, 10
            ),
            abi.encode(0)
        );
        vm.startPrank(MOCK_USER);

        productIrs.initiateTakerOrder(MOCK_ACCOUNT_ID, MOCK_MARKET_ID, maturityTimestamp, 100);
        vm.stopPrank();
    }

    function test_CloseExistingAccount() public {
        productIrs.createPortfolio(MOCK_ACCOUNT_ID);
        test_InitiateTakerOrder();

        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.executeDatedTakerOrder.selector, MOCK_MARKET_ID, maturityTimestamp, -10),
            abi.encode(10, -10)
        );
        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.closePosition.selector, MOCK_MARKET_ID, maturityTimestamp, MOCK_ACCOUNT_ID),
            abi.encode(10, -10)
        );

        vm.prank(address(mockCoreStorage));
        productIrs.closeAccount(MOCK_ACCOUNT_ID, MOCK_QUOTE_TOKEN);
    }

    function test_AccountAnnualizedExposures() public {
        productIrs.createPortfolio(MOCK_ACCOUNT_ID);
        test_InitiateTakerOrder();

        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.getAccountUnfilledBases.selector, MOCK_MARKET_ID, maturityTimestamp, MOCK_ACCOUNT_ID),
            abi.encode(10, 11)
        );
        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.getAccountFilledBalances.selector, MOCK_MARKET_ID, maturityTimestamp, MOCK_ACCOUNT_ID),
            abi.encode(10, 12)
        );

        Account.Exposure[] memory exposures = new Account.Exposure[](1);

        exposures = productIrs.getAccountAnnualizedExposures(MOCK_ACCOUNT_ID, MOCK_QUOTE_TOKEN);

        assertEq(exposures.length, 1);
        assertEq(exposures[0].marketId, MOCK_MARKET_ID);
        assertEq(exposures[0].filled, 20);
        assertEq(exposures[0].unfilledLong, 10);
        assertEq(exposures[0].unfilledShort, 11);
    }

    function test_BaseToAnnualizedExposure() public {
        int256[] memory baseAmounts = new int256[](2);
        baseAmounts[0] = 178;
        baseAmounts[1] = 1.5e18;

        int256[] memory exposures = new int256[](baseAmounts.length);
        exposures = productIrs.baseToAnnualizedExposure(baseAmounts, MOCK_MARKET_ID, maturityTimestamp);

        assertEq(exposures.length, 2);
        assertEq(exposures[0], 178);
        assertEq(exposures[1], 1.5e18);
    }

    function test_AccountUnrealizedPnL() public {
        productIrs.createPortfolio(MOCK_ACCOUNT_ID);
        test_InitiateTakerOrder();

        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.getAccountFilledBalances.selector, MOCK_MARKET_ID, maturityTimestamp, MOCK_ACCOUNT_ID),
            abi.encode(10, 12)
        );
        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.getDatedIRSGwap.selector, MOCK_MARKET_ID, maturityTimestamp),
            abi.encode(UD60x18.wrap(1e18))
        );

        int256 unrealizedPnL = productIrs.getAccountUnrealizedPnL(MOCK_ACCOUNT_ID, MOCK_QUOTE_TOKEN);

        assertEq(unrealizedPnL, 42);
    }

    function test_Name() public {
        string memory name = productIrs.name();

        assertEq(name, "Dated IRS Product");
    }

    function test_Settle() public {
        productIrs.createPortfolio(MOCK_ACCOUNT_ID);
        test_InitiateTakerOrder();

        vm.mockCall(
            address(2),
            abi.encodeWithSelector(IPool.closePosition.selector, MOCK_MARKET_ID, maturityTimestamp, MOCK_ACCOUNT_ID),
            abi.encode(10, -11)
        );
        vm.mockCall(
            address(mockCoreStorage),
            abi.encodeWithSelector(
                IProductModule.propagateCashflow.selector, MOCK_ACCOUNT_ID, MOCK_PRODUCT_ID, MOCK_QUOTE_TOKEN, -1
            ),
            abi.encode()
        );

        vm.warp(maturityTimestamp + 1);
        vm.prank(MOCK_USER);
        productIrs.settle(MOCK_ACCOUNT_ID, MOCK_MARKET_ID, maturityTimestamp);
    }
}

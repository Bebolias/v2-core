//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/modules/LiquidationModule.sol";
import "../test-utils/MockCoreStorage.sol";

contract EnhancedLiquidationModule is LiquidationModule, CoreState { }

contract LiquidationModuleTest is Test {
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    EnhancedLiquidationModule internal liquidationModule;

    uint128 internal constant accountId = 100;

    uint256 internal constant LOW_COLLATERAL = 500e18;
    uint256 internal constant MEDIUM_COLLATERAL = 1000e18;
    uint256 internal constant HIGH_COLLATERAL = 5000e18;

    function setUp() public {
        liquidationModule = new EnhancedLiquidationModule();
        setCollateralProfile("low");
    }

    function setCollateralProfile(string memory profile) internal {
        bool low = keccak256(abi.encodePacked(profile)) == keccak256(abi.encodePacked("low"));
        bool medium = keccak256(abi.encodePacked(profile)) == keccak256(abi.encodePacked("medium"));
        bool high = keccak256(abi.encodePacked(profile)) == keccak256(abi.encodePacked("high"));

        require(low || medium || high, "Unkwown collateral profile type");

        uint256 balance = 0;
        if (low) balance = LOW_COLLATERAL;
        if (medium) balance = MEDIUM_COLLATERAL;
        if (high) balance = HIGH_COLLATERAL;

        // Set up the balance of token 0
        liquidationModule.changeAccountBalance(
            accountId, MockAccountStorage.CollateralBalance({ token: Constants.TOKEN_0, balance: balance })
        );
    }

    function injectZeroExposures() internal {
        // Mock second calls to products
        {
            MockProduct[] memory products = liquidationModule.getProducts();

            // Mock account (id:100) exposures to product (id:1) and markets (ids: 10, 11)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](2);

                mockExposures[0] = Account.Exposure({ marketId: 10, filled: 0, unfilledLong: 0, unfilledShort: -0 });
                mockExposures[1] = Account.Exposure({ marketId: 11, filled: 0, unfilledLong: 0, unfilledShort: 0 });

                products[0].mockGetAccountAnnualizedExposures(100, mockExposures);
            }

            // Mock account (id: 100) unrealized PnL in product (id: 1)
            products[0].mockGetAccountUnrealizedPnL(100, 100e18);

            // Mock account (id:100) exposures to product (id:2) and markets (ids: 20)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

                mockExposures[0] = Account.Exposure({ marketId: 20, filled: 0, unfilledLong: 0, unfilledShort: 0 });

                products[1].mockGetAccountAnnualizedExposures(100, mockExposures);
            }

            // Mock account (id: 100) unrealized PnL in product (id: 2)
            products[1].mockGetAccountUnrealizedPnL(100, -200e18);
        }
    }

    function mockLiquidatorAccount() internal {
        // Mock liquidator account
        uint128 liquidatorId = 101;
        {
            MockAccountStorage.CollateralBalance[] memory balances = new MockAccountStorage.CollateralBalance[](0);
            uint128[] memory activeProductIds = new uint128[](0);

            liquidationModule.mockAccount(liquidatorId, vm.addr(1), balances, activeProductIds, Constants.TOKEN_1);
        }
    }

    function test_Liquidate() public {
        injectZeroExposures();
        mockLiquidatorAccount();

        // Trigger liquidation
        liquidationModule.liquidate(100, 101);

        // Check balances after
        {
            uint256 balance = liquidationModule.getCollateralBalance(100, Constants.TOKEN_0);
            assertEq(balance, LOW_COLLATERAL - 90e18);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(101, Constants.TOKEN_0);
            assertEq(balance, 90e18);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(101, Constants.TOKEN_1);
            assertEq(balance, 0);
        }
    }

    function test_RevertWhen_Liquidate_NoAccount() public {
        injectZeroExposures();
        mockLiquidatorAccount();

        // Trigger liquidation
        vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 99));
        liquidationModule.liquidate(99, 101);
    }

    function test_RevertWhen_Liquidate_AccountNonLiquidatable() public {
        injectZeroExposures();
        mockLiquidatorAccount();
        setCollateralProfile("high");

        // Trigger liquidation
        vm.expectRevert(abi.encodeWithSelector(LiquidationModule.AccountNotLiquidatable.selector, 100));
        liquidationModule.liquidate(100, 101);
    }

    function test_RevertWhen_Liquidate_NoEffect() public {
        mockLiquidatorAccount();

        // Trigger liquidation
        vm.expectRevert(abi.encodeWithSelector(LiquidationModule.AccountExposureNotReduced.selector, 100, 1800e18, 1800e18));
        liquidationModule.liquidate(100, 101);
    }

    function test_RevertWhen_Liquidate_NoLiquidatorAccount() public {
        injectZeroExposures();

        // Trigger liquidation
        vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 101));
        liquidationModule.liquidate(100, 101);
    }
}

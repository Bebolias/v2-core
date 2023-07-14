/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/LiquidationModule.sol";
import "../test-utils/MockCoreStorage.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";

contract EnhancedLiquidationModule is LiquidationModule, CoreState {
    function _extractLiquidatorReward(
        uint128 liquidatedAccountId,
        address collateralType,
        uint256 imPreClose,
        uint256 imPostClose
    ) public returns (uint256) {
        return extractLiquidatorReward(liquidatedAccountId, collateralType, imPreClose, imPostClose);
    }

    function setLiquidationBooster(uint128 accountId, address collateralType, uint256 liquidationBooster) public {
        CollateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationBooster: liquidationBooster,
                tokenAddress: Constants.TOKEN_0,
                cap: Constants.TOKEN_0_CAP
            })
        );

        uint256 balance = this.getCollateralBalance(accountId, collateralType);
        changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: balance,
                liquidationBoosterBalance: liquidationBooster
            })
        );
    }
}

contract LiquidationModuleTest is Test {
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    EnhancedLiquidationModule internal liquidationModule;
    bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";
    address internal owner = vm.addr(1);

    uint128 internal constant accountId = 100;

    uint256 internal constant LOW_COLLATERAL = 500e18;
    uint256 internal constant MEDIUM_COLLATERAL = 1000e18;
    uint256 internal constant HIGH_COLLATERAL = 5000e18;

    function setUp() public {
        liquidationModule = new EnhancedLiquidationModule();
        vm.store(
            address(liquidationModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );
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
            accountId,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: balance,
                liquidationBoosterBalance: Constants.TOKEN_0_LIQUIDATION_BOOSTER
            })
        );
    }

    function injectZeroExposures() internal {
        // Mock second calls to products
        {
            MockProduct[] memory products = liquidationModule.getProducts();

            // Mock account (id:100) exposures to product (id:1) and markets (ids: 10, 11)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](2);

                mockExposures[0] = Account.Exposure(
                    {productId: 1, marketId: 10, annualizedNotional: 0, unrealizedLoss: 0}
                );
                mockExposures[1] = Account.Exposure(
                    {productId: 1, marketId: 11, annualizedNotional: 0, unrealizedLoss: 0}
                );

                products[0].mockGetAccountTakerAndMakerExposures(
                    100, Constants.TOKEN_0, mockExposures, mockExposures, mockExposures
                );
            }

            // Mock account (id:100) exposures to product (id:2) and markets (ids: 20)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

                mockExposures[0] = Account.Exposure(
                    {productId: 2, marketId: 20, annualizedNotional: 0, unrealizedLoss: 0}
                );

                products[1].mockGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0, mockExposures, mockExposures, mockExposures);
            }

            // todo: test single account single-token mode (AN)
        }
    }

    function injectPartialExposures() internal {
        // Mock second calls to products
        {
            MockProduct[] memory products = liquidationModule.getProducts();

            // Mock account (id:100) exposures to product (id:1) and markets (ids: 10, 11)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](2);

                mockExposures[0] = Account.Exposure(
                     {productId: 1, marketId: 10, annualizedNotional: 20e18, unrealizedLoss: 0}
                );
                mockExposures[1] = Account.Exposure(
                    {productId: 1, marketId: 11, annualizedNotional: 2e18, unrealizedLoss: 0}
                );

                products[0].mockGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0, mockExposures, mockExposures, mockExposures);
            }


            // Mock account (id:100) exposures to product (id:2) and markets (ids: 20)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

                mockExposures[0] = Account.Exposure(
                    {productId: 2, marketId: 20, annualizedNotional: -5e18, unrealizedLoss: 0}
                );

                products[1].mockGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0, mockExposures, mockExposures, mockExposures);
            }

            // todo: test single account single-token mode (AN)
        }
    }

    function mockLiquidatorAccount() internal {
        // Mock liquidator account
        uint128 liquidatorId = 888;
        {
            MockAccountStorage.CollateralBalance[] memory balances = new MockAccountStorage.CollateralBalance[](0);
            uint128[] memory activeProductIds = new uint128[](0);

            liquidationModule.mockAccount(liquidatorId, vm.addr(1), balances, activeProductIds);
        }
    }

    function test_ExtractLiquidatorReward_SmallPosition_FullyLiquidated() public {
        uint256 liquidatorReward = liquidationModule._extractLiquidatorReward(100, Constants.TOKEN_0, 100e18, 0);
        assertEq(liquidatorReward, Constants.TOKEN_0_LIQUIDATION_BOOSTER);
        assertEq(liquidationModule.getCollateralBalance(100, Constants.TOKEN_0), LOW_COLLATERAL);
        assertEq(liquidationModule.getLiquidationBoosterBalance(100, Constants.TOKEN_0), 0);
    }

    function test_RevertWhen_ExtractLiquidatorReward_SmallPosition_PartiallyLiquidated() public {
        vm.expectRevert(
            abi.encodeWithSelector(ILiquidationModule.PartialLiquidationNotIncentivized.selector, 100, 100e18, 1)
        );
        liquidationModule._extractLiquidatorReward(100, Constants.TOKEN_0, 100e18, 1);
    }

    function test_ExtractLiquidatorReward_BigPosition_FullyLiquidated() public {
        uint256 liquidatorReward = liquidationModule._extractLiquidatorReward(100, Constants.TOKEN_0, 300e18, 0);
        assertEq(liquidatorReward, 15e18);
        assertEq(liquidationModule.getCollateralBalance(100, Constants.TOKEN_0), LOW_COLLATERAL - 15e18);
        assertEq(
            liquidationModule.getLiquidationBoosterBalance(100, Constants.TOKEN_0),
            Constants.TOKEN_0_LIQUIDATION_BOOSTER
        );
    }

    function test_ExtractLiquidatorReward_BigPosition_PartiallyLiquidated() public {
        uint256 liquidatorReward = liquidationModule._extractLiquidatorReward(100, Constants.TOKEN_0, 300e18, 200e18);
        assertEq(liquidatorReward, 5e18);
        assertEq(liquidationModule.getCollateralBalance(100, Constants.TOKEN_0), LOW_COLLATERAL - 5e18);
        assertEq(
            liquidationModule.getLiquidationBoosterBalance(100, Constants.TOKEN_0),
            Constants.TOKEN_0_LIQUIDATION_BOOSTER
        );
    }

    function test_RevertWhen_ExtractLiquidatorReward_SmallPosition() public {
        liquidationModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: 0,
                liquidationBoosterBalance: Constants.TOKEN_0_LIQUIDATION_BOOSTER - 1
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Collateral.InsufficientLiquidationBoosterBalance.selector, Constants.TOKEN_0_LIQUIDATION_BOOSTER
            )
        );
        liquidationModule._extractLiquidatorReward(100, Constants.TOKEN_0, 100e18, 0);
    }

    function test_RevertWhen_ExtractLiquidatorReward_BigPosition() public {
        liquidationModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: 15e18 - 1,
                liquidationBoosterBalance: 0
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, 15e18));
        liquidationModule._extractLiquidatorReward(100, Constants.TOKEN_0, 300e18, 0);
    }

    function test_Liquidate_BigPosition() public {
        injectZeroExposures();
        mockLiquidatorAccount();

        // Trigger liquidation
        uint256 liquidatorReward = liquidationModule.liquidate(100, 888, Constants.TOKEN_0);
        assertEq(liquidatorReward, 100e18);

        //    imPreClose: 2000e18
        //    imPostClose: 0
        //    imDelta: 1892e18
        //    liquidator reward parameter = 0.05
        //    liquidator reward = 100e18

        // Check balances after
        {
            uint256 balance = liquidationModule.getCollateralBalance(100, Constants.TOKEN_0);
            assertEq(balance, LOW_COLLATERAL - 100e18);
        }

        {
            uint256 liquidationBooster = liquidationModule.getLiquidationBoosterBalance(100, Constants.TOKEN_0);
            assertEq(liquidationBooster, Constants.TOKEN_0_LIQUIDATION_BOOSTER);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(888, Constants.TOKEN_0);
            assertEq(balance, 100e18);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(888, Constants.TOKEN_1);
            assertEq(balance, 0);
        }
    }

    function test_Liquidate_BigPosition_Partial() public {
        injectPartialExposures();
        mockLiquidatorAccount();

        // Trigger liquidation
        uint256 liquidatorReward = liquidationModule.liquidate(100, 888, Constants.TOKEN_0);

        //    imPreClose: 2000e18
        //    imPostClose: 108e18
        //    imDelta: 1892e18
        //    liquidator reward parameter = 0.05
        //   liquidator reward = 94.6e18

        assertEq(liquidatorReward, 946e17);

        // Check balances after
        {
            uint256 balance = liquidationModule.getCollateralBalance(100, Constants.TOKEN_0);
            assertEq(balance, LOW_COLLATERAL - 946e17);
        }

        {
            uint256 liquidationBooster = liquidationModule.getLiquidationBoosterBalance(100, Constants.TOKEN_0);
            assertEq(liquidationBooster, Constants.TOKEN_0_LIQUIDATION_BOOSTER);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(888, Constants.TOKEN_0);
            assertEq(balance, 946e17);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(888, Constants.TOKEN_1);
            assertEq(balance, 0);
        }
    }

    function test_Liquidate_SmallPosition() public {
        injectZeroExposures();
        mockLiquidatorAccount();
        liquidationModule.setLiquidationBooster(100, Constants.TOKEN_0, 101e18);

        // Trigger liquidation
        uint256 liquidatorReward = liquidationModule.liquidate(100, 888, Constants.TOKEN_0);
        assertEq(liquidatorReward, 101e18);

        // Check balances after
        {
            uint256 balance = liquidationModule.getCollateralBalance(100, Constants.TOKEN_0);
            assertEq(balance, LOW_COLLATERAL);
        }

        {
            uint256 liquidationBooster = liquidationModule.getLiquidationBoosterBalance(100, Constants.TOKEN_0);
            assertEq(liquidationBooster, 0);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(888, Constants.TOKEN_0);
            assertEq(balance, 101e18);
        }

        {
            uint256 balance = liquidationModule.getCollateralBalance(888, Constants.TOKEN_1);
            assertEq(balance, 0);
        }
    }

    function test_RevertWhen_Liquidate_Global_Deny_All() public {
        vm.prank(owner);
        liquidationModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );

        liquidationModule.liquidate(1, 2, Constants.TOKEN_0);

    }

    function test_RevertWhen_Liquidate_SmallPosition_Partial() public {
        injectPartialExposures();
        mockLiquidatorAccount();
        liquidationModule.setLiquidationBooster(100, Constants.TOKEN_0, 101e18);

        vm.expectRevert(
                abi.encodeWithSelector(ILiquidationModule.PartialLiquidationNotIncentivized.selector, 100, 2000e18, 108e18)
            );
            liquidationModule.liquidate(100, 888, Constants.TOKEN_0);
    }

    function test_RevertWhen_Liquidate_NoAccount() public {
        injectZeroExposures();
        mockLiquidatorAccount();

        // Trigger liquidation
        vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 99));
        liquidationModule.liquidate(99, 888, Constants.TOKEN_0);
    }

    function test_RevertWhen_Liquidate_AccountNonLiquidatable() public {
        injectZeroExposures();
        mockLiquidatorAccount();
        setCollateralProfile("high");

        // Trigger liquidation
        vm.expectRevert(abi.encodeWithSelector(ILiquidationModule.AccountNotLiquidatable.selector, 100));
        liquidationModule.liquidate(100, 888, Constants.TOKEN_0);
    }

    function test_RevertWhen_Liquidate_NoEffect() public {
        mockLiquidatorAccount();

        // Trigger liquidation
        vm.expectRevert(
            abi.encodeWithSelector(ILiquidationModule.AccountExposureNotReduced.selector, 100, 2000e18, 2000e18, 0, 0)
        );
        liquidationModule.liquidate(100, 888, Constants.TOKEN_0);
    }

    function test_RevertWhen_Liquidate_NoLiquidatorAccount() public {
        injectZeroExposures();

        vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 434343));
        liquidationModule.liquidate(100, 434343, Constants.TOKEN_0);
    }
}

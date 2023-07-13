/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/CollateralModule.sol";
import "../test-utils/MockCoreStorage.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";

contract EnhancedCollateralModule is CollateralModule, CoreState {
    function enableDepositing(address tokenAddress) public {
        CollateralConfiguration.Data memory config = CollateralConfiguration.load(tokenAddress);
        CollateralConfiguration.set(
            CollateralConfiguration.Data({
                depositingEnabled: true,
                liquidationBooster: config.liquidationBooster,
                tokenAddress: tokenAddress,
                cap: config.cap
            })
        );
    }
}

contract CollateralModuleTest is Test {
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";

    address internal owner = vm.addr(1);

    event Deposited(
        uint128 indexed accountId,
        address indexed collateralType,
        uint256 tokenAmount,
        address indexed sender,
        uint256 blockTimestamp
    );
    event Withdrawn(
        uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender, uint256 blockTimestamp
    );

    EnhancedCollateralModule internal collateralModule;

    function setUp() public {
        collateralModule = new EnhancedCollateralModule();

        vm.store(
            address(collateralModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );
    }

    function changeIMRequirementToZero() internal {
        // Mock second calls to products
        {
            MockProduct[] memory products = collateralModule.getProducts();

            // Mock account (id:100) exposures to product (id:1) and markets (ids: 10, 11)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](2);

                mockExposures[0] = Account.Exposure(
                    {productId: 1, marketId: 10, annualizedNotional: 0, lockedPrice: 1e18, marketTwap: 1e18}
                );
                mockExposures[1] = Account.Exposure(
                    {productId: 1, marketId: 11, annualizedNotional: 0, lockedPrice: 1e18, marketTwap: 1e18}
                );

                // todo: currently using mockExposures for mockTakerExposures, mockMakerExposuresLower and mockMakerExposuresUpper
                products[0].mockGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0, mockExposures, mockExposures, mockExposures);
                products[0].skipGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0); // skip old mock
            }


            // Mock account (id:100) exposures to product (id:2) and markets (ids: 20)
            {
                Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

                mockExposures[0] = Account.Exposure(
                    {productId: 2, marketId: 20, annualizedNotional: 0, lockedPrice: 1e18, marketTwap: 1e18}
                );

                products[1].mockGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0, mockExposures, mockExposures, mockExposures);
                products[1].skipGetAccountTakerAndMakerExposures(100, Constants.TOKEN_0); // skip old mock
            }

            // todo: test single account single-token mode (AN)
        }
    }

    function test_GetAccountCollateralBalance() public {
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE
        );
    }

    function test_GetAccountCollateralBalance_NoSettlementToken() public {
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_1), Constants.DEFAULT_TOKEN_1_BALANCE
        );
    }


    function test_GetAccountCollateralBalanceAvailable() public {
        uint256 unrealizedLoss = 0;
        uint256 im = 2000e18;

        // first market (marketId 10, productId 1
        // risk parameter = 1
        //  liquidationMarginRequirementExposureLower: 100e18 (annualized notional = -100e18)
        //  liquidationMarginRequirementExposureUpper: 300e18 (annualized notional = 300e18)

        // second market
        // risk parameter = 1
        //  liquidationMarginRequirementExposureLower: 500e18 (annualized notional = 500e18)
        //  liquidationMarginRequirementExposureUpper: 0

        // third market
        // risk parameter = 1
        //  liquidationMarginRequirementExposureLower: 200e18 (annualized notional = -200e18)
        //  liquidationMarginRequirementExposureUpper: 100e18 (annualized notional = 100e18)

        // total lm = 300e18 + 500e18 + 200e18= 1000e18
        // im mutliplier = 2
        // im = 1000e18 * 2 = 2000e18

        assertEq(
            collateralModule.getAccountCollateralBalanceAvailable(100, Constants.TOKEN_0),
            Constants.DEFAULT_TOKEN_0_BALANCE - unrealizedLoss - im
        );
    }

    function test_GetAccountCollateralBalanceAvailable_NoSettlementToken() public {
        assertEq(
            collateralModule.getAccountCollateralBalanceAvailable(100, Constants.TOKEN_1),
            Constants.DEFAULT_TOKEN_1_BALANCE
        );
    }

    function test_GetAccountCollateralBalanceAvailable_OtherToken() public {
        assertEq(collateralModule.getAccountCollateralBalanceAvailable(100, Constants.TOKEN_UNKNOWN), 0);
    }

    function test_deposit_Collateral() public {

        uint256 depositAmount = 500e18;
        uint256 boosterAmount = 0;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: 0,
                liquidationBoosterBalance: 10e18
            })
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, depositAmount + boosterAmount, depositor, block.timestamp);

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);

        // Check the collateral balance post deposit
        assertEq(collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), depositAmount);
        assertEq(collateralModule.getAccountLiquidationBoosterBalance(100, Constants.TOKEN_0), 10e18);
    }

    function test_depositCollateralDenyAllExpectReverts() public {

        vm.prank(owner);
        collateralModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );

        collateralModule.deposit(1,address(0),1e18);

    }

    function test_withdrawCollateralDenyAllExpectReverts() public {

        vm.prank(owner);
        collateralModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );

        collateralModule.withdraw(1,address(0),1e18);

    }



    function test_deposit_CollateralAndLiquidationBooster() public {
        uint256 depositAmount = 500e18;
        uint256 boosterAmount = 10e18;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({token: Constants.TOKEN_0, balance: 0, liquidationBoosterBalance: 0})
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, depositAmount + boosterAmount, depositor, block.timestamp);

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);

        // Check the collateral balance post deposit
        assertEq(collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), depositAmount);
        assertEq(collateralModule.getAccountLiquidationBoosterBalance(100, Constants.TOKEN_0), boosterAmount);
    }

    function test_deposit_LiquidationBooster() public {
        uint256 depositAmount = 0;
        uint256 boosterAmount = 10e18;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({token: Constants.TOKEN_0, balance: 0, liquidationBoosterBalance: 0})
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, depositAmount + boosterAmount, depositor, block.timestamp);

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);

        // Check the collateral balance post deposit
        assertEq(collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), depositAmount);
        assertEq(collateralModule.getAccountLiquidationBoosterBalance(100, Constants.TOKEN_0), boosterAmount);
    }

    function test_deposit_CollateralAndPartialBooster() public {
        uint256 depositAmount = 100e18;
        uint256 boosterAmount = 3e18;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({token: Constants.TOKEN_0, balance: 0, liquidationBoosterBalance: 7e18})
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, depositAmount + boosterAmount, depositor, block.timestamp);

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);

        // Check the collateral balance post deposit
        assertEq(collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), depositAmount);
        assertEq(collateralModule.getAccountLiquidationBoosterBalance(100, Constants.TOKEN_0), boosterAmount + 7e18);
    }

    function test_RevertWhen_deposit_Collateral_InsufficientAllowance() public {
        uint256 depositAmount = 500e18;
        uint256 boosterAmount = 0;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: 0,
                liquidationBoosterBalance: 10e18
            })
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount - 1)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20.InsufficientAllowance.selector, depositAndBoosterAmount, depositAndBoosterAmount - 1
            )
        );

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);
    }

    function test_RevertWhen_deposit_CollateralAndLiquidationBooster_InsufficientAllowance() public {
        uint256 depositAmount = 500e18;
        uint256 boosterAmount = 10e18;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({token: Constants.TOKEN_0, balance: 0, liquidationBoosterBalance: 0})
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount - 1)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20.InsufficientAllowance.selector, depositAndBoosterAmount, depositAndBoosterAmount - 1
            )
        );

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);
    }

    function test_RevertWhen_deposit_LiquidationBooster_InsufficientAllowance() public {
        uint256 depositAmount = 0;
        uint256 boosterAmount = 10e18;
        uint256 depositAndBoosterAmount = depositAmount + boosterAmount;
        address depositor = Constants.ALICE;
        collateralModule.changeAccountBalance(
            100,
            MockAccountStorage.CollateralBalance({token: Constants.TOKEN_0, balance: 0, liquidationBoosterBalance: 0})
        );

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(depositAndBoosterAmount - 1)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, depositAndBoosterAmount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20.InsufficientAllowance.selector, depositAndBoosterAmount, depositAndBoosterAmount - 1
            )
        );

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, depositAmount);
    }

    function testFuzz_Deposit(address depositor) public {
        // Amount to deposit
        uint256 amount = 500e18;

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount),
            abi.encode()
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect Deposited event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, amount, depositor, block.timestamp);

        // Deposit
        collateralModule.deposit(100, Constants.TOKEN_0, amount);

        // Check the collateral balance post deposit
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0),
            Constants.DEFAULT_TOKEN_0_BALANCE + amount
        );
    }

    function testFuzz_RevertWhen_Deposit_WithNotEnoughAllowance(address depositor) public {
        // Amount to deposit
        uint256 amount = 500e18;

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(0)
        );

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect revert due to insufficient allowance
        vm.expectRevert(abi.encodeWithSelector(IERC20.InsufficientAllowance.selector, amount, 0));
        collateralModule.deposit(100, Constants.TOKEN_0, amount);
    }

    function testFuzz_RevertWhen_Deposit_WithCollateralTypeNotEnabled(address depositor) public {
        // Amount to deposit
        uint256 amount = 500e18;

        // Route the deposit from depositor
        vm.prank(depositor);

        // Expect revert due to unsupported collateral type
        vm.expectRevert(
            abi.encodeWithSelector(CollateralConfiguration.CollateralDepositDisabled.selector, Constants.TOKEN_1)
        );
        collateralModule.deposit(100, Constants.TOKEN_1, amount);
    }

    function test_Withdraw_Collateral() public {
        // Amount to withdraw
        uint256 amount = 500e18;

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.transfer.selector, Constants.ALICE, amount), abi.encode()
        );

        // Route the deposit from Alice
        vm.prank(Constants.ALICE);

        // Expect Withdrawn event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Withdrawn(100, Constants.TOKEN_0, amount, Constants.ALICE, block.timestamp);

        // Withdraw
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);

        // Check the collateral balance post withdraw
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0),
            Constants.DEFAULT_TOKEN_0_BALANCE - amount
        );
    }

    function test_Withdraw_CollateralAndLiquidationBooster() public {
        changeIMRequirementToZero();

        // Amount to withdraw
        uint256 amount = 10000e18 + 10e18;
        address user = Constants.ALICE;

        // Mock ERC20 external calls
        vm.mockCall(Constants.TOKEN_0, abi.encodeWithSelector(IERC20.transfer.selector, user, amount), abi.encode());

        vm.prank(user);

        // Expect Withdrawn event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Withdrawn(100, Constants.TOKEN_0, amount, user, block.timestamp);

        // Withdraw
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);

        // Check the collateral balance post withdraw
        assertEq(collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), 0);
        assertEq(collateralModule.getAccountLiquidationBoosterBalance(100, Constants.TOKEN_0), 0);
    }

    function test_Withdraw_CollateralAndPartialLiquidationBooster() public {
        changeIMRequirementToZero();

        // Amount to withdraw
        uint256 amount = 10000e18 + 3e18;
        address user = Constants.ALICE;

        // Mock ERC20 external calls
        vm.mockCall(Constants.TOKEN_0, abi.encodeWithSelector(IERC20.transfer.selector, user, amount), abi.encode());

        vm.prank(user);

        // Expect Withdrawn event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Withdrawn(100, Constants.TOKEN_0, amount, user, block.timestamp);

        // Withdraw
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);

        // Check the collateral balance post withdraw
        assertEq(collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), 0);
        assertEq(collateralModule.getAccountLiquidationBoosterBalance(100, Constants.TOKEN_0), 7e18);
    }

    function test_RevertWhen_Withdraw_InsufficientCollateralAndLiquidationBooster() public {
        changeIMRequirementToZero();

        // Amount to withdraw
        uint256 amount = 10000e18 + 11e18;
        address user = Constants.ALICE;

        // Mock ERC20 external calls
        vm.mockCall(Constants.TOKEN_0, abi.encodeWithSelector(IERC20.transfer.selector, user, amount), abi.encode());

        vm.prank(user);

        // Expect Withdrawn event
        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientLiquidationBoosterBalance.selector, 11e18));

        // Withdraw
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_RevertWhen_Withdraw_InsufficientCollateralAndLiquidationBooster_LargeUPnL() public {
        changeIMRequirementToZero();
        MockProduct[] memory products = collateralModule.getProducts();

        // Amount to withdraw
        uint256 amount = 10000e18 + 11e18;
        address user = Constants.ALICE;

        // Mock ERC20 external calls
        vm.mockCall(Constants.TOKEN_0, abi.encodeWithSelector(IERC20.transfer.selector, user, amount), abi.encode());

        vm.prank(user);

        // Expect Withdrawn event
        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientLiquidationBoosterBalance.selector, 11e18));

        // Withdraw
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_RevertWhen_Withdraw_UnautohorizedAccount(address otherAddress) public {
        vm.assume(otherAddress != Constants.ALICE);
        vm.assume(otherAddress != Constants.PERIPHERY);

        // Amount to withdraw
        uint256 amount = 500e18;

        // Route the deposit from other address
        vm.prank(otherAddress);

        // Expect revert due to unauthorized account
        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, otherAddress));
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_Withdraw_FromPeriphery() public {
        // Amount to withdraw
        uint256 amount = 500e18;

        // Mock ERC20 external calls
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.transfer.selector, Constants.PERIPHERY, amount), abi.encode()
        );

        // Route the deposit from Alice
        vm.prank(Constants.PERIPHERY);

        // Expect Withdrawn event
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Withdrawn(100, Constants.TOKEN_0, amount, Constants.PERIPHERY, block.timestamp);

        // Withdraw
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);

        // Check the collateral balance post withdraw
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0),
            Constants.DEFAULT_TOKEN_0_BALANCE - amount
        );
    }

    function test_RevertWhen_Withdraw_MoreThanBalance() public {
        // Amount to withdraw
        uint256 amount = 10500e18;

        // Route the deposit from Alice
        vm.prank(Constants.ALICE);

        // Expect revert due to insufficient collateral balance
        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientLiquidationBoosterBalance.selector, 500e18));
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_RevertWhen_Withdraw_WhenIMNoLongerSatisfied() public {
        // Amount to withdraw
        uint256 amount = 9500e18;

        // Route the deposit from Alice
        vm.prank(Constants.ALICE);

        // Expect revert due to insufficient margin coverage
        vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, 100, Constants.TOKEN_0, 2000e18, 0));
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_RevertWhen_CapExceeded_Deposit() public {
        address depositor = address(1);
        uint256 amount = Constants.TOKEN_0_CAP + 1;

        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount),
            abi.encode()
        );
        vm.prank(depositor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICollateralModule.CollateralCapExceeded.selector, Constants.TOKEN_0, Constants.TOKEN_0_CAP, 0, amount, 0
            )
        );
        collateralModule.deposit(100, Constants.TOKEN_0, amount);
    }

    function test_RevertWhen_CapExceeded_MultipleDeposits() public {
        address depositor = address(1);
        uint256 amount = Constants.TOKEN_0_CAP / 2;

        // First Deposit
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount),
            abi.encode()
        );
        vm.prank(depositor);
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, amount, depositor, block.timestamp);
        collateralModule.deposit(100, Constants.TOKEN_0, amount);

        // Second Deposit
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(amount)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount + 1)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount + 1),
            abi.encode()
        );
        vm.prank(depositor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICollateralModule.CollateralCapExceeded.selector,
                Constants.TOKEN_0,
                Constants.TOKEN_0_CAP,
                amount,
                amount + 1,
                0
            )
        );
        collateralModule.deposit(100, Constants.TOKEN_0, amount + 1);
    }

    function test_Deposit_DifferentCaps() public {
        address depositor = address(1);

        // Deposit Token 0
        uint256 amount = Constants.TOKEN_0_CAP;
        vm.mockCall(
            Constants.TOKEN_0, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount)
        );
        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount),
            abi.encode()
        );

        vm.prank(depositor);
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, amount, depositor, block.timestamp);
        collateralModule.deposit(100, Constants.TOKEN_0, amount);

        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0),
            Constants.DEFAULT_TOKEN_0_BALANCE + amount
        );

        // Deposit Token 1
        collateralModule.enableDepositing(Constants.TOKEN_1);
        amount = Constants.TOKEN_1_CAP;
        vm.mockCall(
            Constants.TOKEN_1, abi.encodeWithSelector(IERC20.balanceOf.selector, collateralModule), abi.encode(0)
        );
        vm.mockCall(
            Constants.TOKEN_1,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount)
        );
        vm.mockCall(
            Constants.TOKEN_1,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount),
            abi.encode()
        );

        vm.prank(depositor);
        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_1, amount, depositor, block.timestamp);
        collateralModule.deposit(100, Constants.TOKEN_1, amount);

        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_1),
            Constants.DEFAULT_TOKEN_1_BALANCE + amount
        );
    }
}

/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/Account.sol";
import "../test-utils/MockCoreStorage.sol";

import {SD59x18} from "@prb/math/SD59x18.sol";
import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";

contract ExposedAccounts is CoreState {
    using Account for Account.Data;

    // Exposed functions
    function load(uint128 id) external pure returns (bytes32 s) {
        Account.Data storage account = Account.load(id);
        assembly {
            s := account.slot
        }
    }

    function create(uint128 id, address owner) external returns (bytes32 s) {
        Account.Data storage account = Account.create(id, owner);
        assembly {
            s := account.slot
        }
    }

    function exists(uint128 id) external view returns (bytes32 s) {
        Account.Data storage account = Account.exists(id);
        assembly {
            s := account.slot
        }
    }

    function closeAccount(uint128 id, address collateralType) external {
        Account.load(id).closeAccount(collateralType);
    }

    function getCollateralBalanceAvailable(uint128 id, address collateralType) external returns (uint256) {
        Account.Data storage account = Account.load(id);
        return account.getCollateralBalanceAvailable(collateralType);
    }

    function loadAccountAndValidateOwnership(uint128 id, address senderAddress) external view returns (bytes32 s) {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(id, senderAddress);
        assembly {
            s := account.slot
        }
    }

    function loadAccountAndValidatePermission(uint128 id, bytes32 permission, address senderAddress)
        external
        view
        returns (bytes32 s)
    {
        Account.Data storage account = Account.loadAccountAndValidatePermission(id, permission, senderAddress);
        assembly {
            s := account.slot
        }
    }

    function getProductTakerAndMakerExposures(uint128 id, uint128 productId, address collateralType)
        external
        returns (
            Account.Exposure[] memory productTakerExposures,
            Account.Exposure[] memory productMakerExposuresLower,
            Account.Exposure[] memory productMakerExposuresUpper
        )
    {
        Account.Data storage account = Account.load(id);
        return account.getProductTakerAndMakerExposures(productId, collateralType);
    }


    function getRiskParameter(uint128 productId, uint128 marketId) external view returns (UD60x18) {
        return Account.getRiskParameter(productId, marketId);
    }

    function getIMMultiplier() external view returns (UD60x18) {
        return Account.getIMMultiplier();
    }

    function imCheck(uint128 id, address collateralType) external {
        Account.Data storage account = Account.load(id);
        account.imCheck(collateralType);
    }

    function isIMSatisfied(uint128 id, address collateralType) external returns (bool, uint256, uint256) {
        Account.Data storage account = Account.load(id);
        return account.isIMSatisfied(collateralType);
    }

    function isLiquidatable(uint128 id, address collateralType) external returns (bool, uint256, uint256, uint256) {
        Account.Data storage account = Account.load(id);
        return account.isLiquidatable(collateralType);
    }

    function getMarginRequirementsAndHighestUnrealizedLoss(uint128 id, address collateralType) 
        external 
        returns (uint256 initialMarginRequirement, uint256 liquidationMarginRequirement, uint256 highestUnrealizedLoss) {
        Account.Data storage account = Account.load(id);
        return account.getMarginRequirementsAndHighestUnrealizedLoss(collateralType);
    }

    function computeLMAndUnrealizedLossFromExposures(Account.Exposure[] memory exposures)
    external
    view
    returns (uint256 liquidationMarginRequirement, uint256 unrealizedLoss)
    {
        return Account.computeLMAndUnrealizedLossFromExposures(exposures);
    }

    function computeLMAndHighestUnrealizedLossFromLowerAndUpperExposures(
        Account.Exposure[] memory exposuresLower,
        Account.Exposure[] memory exposuresUpper
    ) external view
    returns (uint256 liquidationMarginRequirement, uint256 highestUnrealizedLoss)
    {
        return Account.computeLMAndHighestUnrealizedLossFromLowerAndUpperExposures(exposuresLower, exposuresUpper);
    }

    function computeLiquidationMarginRequirement(int256 annualizedNotional, UD60x18 riskParameter)
    external
    pure
    returns (uint256 liquidationMarginRequirement)
    {
       
        return Account.computeLiquidationMarginRequirement(annualizedNotional, riskParameter);
    }

    function computeInitialMarginRequirement(uint256 liquidationMarginRequirement, UD60x18 imMultiplier)
    external
    pure
    returns (uint256 initialMarginRequirement)
    {
        return Account.computeInitialMarginRequirement(liquidationMarginRequirement, imMultiplier);
    }
}

contract AccountTest is Test {
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    ExposedAccounts internal accounts;

    uint128 internal constant accountId = 100;
    bytes32 internal constant accountSlot = keccak256(abi.encode("xyz.voltz.Account", accountId));

    uint256 internal constant LOW_COLLATERAL = 500e18;
    uint256 internal constant MEDIUM_COLLATERAL = 1000e18;
    uint256 internal constant HIGH_COLLATERAL = 5000e18;

    function setUp() public {
        accounts = new ExposedAccounts();
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
        accounts.changeAccountBalance(
            accountId,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_0,
                balance: balance,
                liquidationBoosterBalance: Constants.TOKEN_0_LIQUIDATION_BOOSTER
            })
        );
    }

    function test_Exists() public {
        bytes32 slot = accounts.exists(accountId);

        assertEq(slot, accountSlot);
    }

    function testFail_load_ZeroAccount() public view {
        accounts.load(0);
    }

    function testFail_exists_ZeroAccount() public view {
        accounts.exists(0);
    }

    function testFail_create_ZeroAccount() public {
        accounts.create(0, address(1));
    }

    function test_RevertWhen_AccountDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 1));

        accounts.exists(1);
    }

    function test_GetCollateralBalance() public {
        uint256 collateralBalance = accounts.getCollateralBalance(accountId, Constants.TOKEN_0);

        assertEq(collateralBalance, LOW_COLLATERAL);
    }

    function test_GetCollateralBalance_NonSettlementToken() public {
        uint256 collateralBalance = accounts.getCollateralBalance(accountId, Constants.TOKEN_1);

        assertEq(collateralBalance, Constants.DEFAULT_TOKEN_1_BALANCE);
    }

    function testFuzz_GetCollateralBalance_NoCollateral(address otherToken) public {
        vm.assume(otherToken != Constants.TOKEN_0);
        vm.assume(otherToken != Constants.TOKEN_1);

        uint256 collateralBalance = accounts.getCollateralBalance(accountId, otherToken);

        assertEq(collateralBalance, 0);
    }

    function test_LoadAccountAndValidateOwnership() public {
        vm.prank(Constants.ALICE);
        bytes32 slot = accounts.loadAccountAndValidateOwnership(accountId, Constants.ALICE);

        assertEq(slot, accountSlot);
    }

    function testFuzz_RevertWhen_LoadAccountAndValidateOwnership(address randomUser) public {
        vm.assume(randomUser != Constants.ALICE);

        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, accountId, randomUser));
        accounts.loadAccountAndValidateOwnership(accountId, randomUser);
    }

    function test_LoadAccountAndValidatePermission() public {
        vm.prank(Constants.ALICE);
        bytes32 slot =
            accounts.loadAccountAndValidatePermission(accountId, AccountRBAC._ADMIN_PERMISSION, Constants.ALICE);

        assertEq(slot, accountSlot);
    }

    function testFuzz_RevertWhen_LoadAccountAndValidatePermission(address randomUser) public {
        vm.assume(randomUser != Constants.ALICE);
        vm.assume(randomUser != Constants.PERIPHERY);

        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, accountId, randomUser));
        accounts.loadAccountAndValidatePermission(accountId, AccountRBAC._ADMIN_PERMISSION, randomUser);

        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accounts.loadAccountAndValidatePermission(accountId, bytes32("PER123"), Constants.ALICE);
    }

    function test_CloseAccount() public {
        accounts.closeAccount(accountId, Constants.TOKEN_0);
        accounts.closeAccount(accountId, Constants.TOKEN_1);
    }

    function test_GetProductTakerAndMakerExposures() public {
        (
        Account.Exposure[] memory productTakerExposures,
        Account.Exposure[] memory productMakerExposuresLower,
        Account.Exposure[] memory productMakerExposuresUpper
        ) = accounts.getProductTakerAndMakerExposures(accountId, 1, Constants.TOKEN_0);

        assertEq(productTakerExposures.length, 0);
        assertEq(productMakerExposuresLower.length, 2);
        assertEq(productMakerExposuresUpper.length, 2);
    }

    function test_GetRiskParameter() public {
        UD60x18 riskParameter = accounts.getRiskParameter(1, 10);

        assertEq(UD60x18.unwrap(riskParameter), 1e18);
    }

    function test_GetIMMultiplier() public {
        UD60x18 imMultiplier = accounts.getIMMultiplier();

        assertEq(UD60x18.unwrap(imMultiplier), 2e18);
    }

    function test_GetMarginRequirementsAndHighestUnrealizedLoss() public {
        (uint256 initialMarginRequirement, uint256 liquidationMarginRequirement, uint256 highestUnrealizedLoss) =
            accounts.getMarginRequirementsAndHighestUnrealizedLoss(accountId, Constants.TOKEN_0);

        assertEq(initialMarginRequirement, 2000e18);
        assertEq(liquidationMarginRequirement, 1000e18);
        assertEq(highestUnrealizedLoss, 0);
    }

    function test_IsLiquidatable_True() public {
        setCollateralProfile("low");

        (bool liquidatable, uint256 im, uint256 lm, uint256 highestUnrealizedLoss) =
             accounts.isLiquidatable(accountId, Constants.TOKEN_0);

        assertEq(liquidatable, true);
        assertEq(lm, 1000e18);
        assertEq(im, 2000e18);
    }

    function test_IsLiquidatable_False() public {
        setCollateralProfile("medium");

        (bool liquidatable, uint256 im, uint256 lm, uint256 highestUnrealizedLoss) = 
            accounts.isLiquidatable(accountId, Constants.TOKEN_0);

        assertEq(liquidatable, false);
        assertEq(lm, 1000e18);
        assertEq(im, 2000e18);
    }

    function test_IsIMSatisfied_False() public {
        setCollateralProfile("medium");

        (bool imSatisfied, uint256 im, uint256 highestUnrealizedLoss) = 
            accounts.isIMSatisfied(accountId, Constants.TOKEN_0);

        assertEq(imSatisfied, false);
        assertEq(im, 2000e18);
        // todo: assert highestUnrealizedLoss
    }

    function test_IsIMSatisfied_True() public {
        setCollateralProfile("high");

        (bool imSatisfied, uint256 im, uint256 highestUnrealizedLoss) =
            accounts.isIMSatisfied(accountId, Constants.TOKEN_0);

        assertEq(imSatisfied, true);
        assertEq(im, 2000e18);
        // todo: assert highestUnrealizedLoss
    }

    function test_RevertWhen_ImCheck_False() public {
        setCollateralProfile("medium");

        vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, accountId, Constants.TOKEN_0, 2000e18, 0));
        accounts.imCheck(accountId, Constants.TOKEN_0);
    }

    function test_ImCheck() public {
        setCollateralProfile("high");

        accounts.imCheck(accountId, Constants.TOKEN_0);
    }

    function test_GetCollateralBalanceAvailable_Positive() public {
        setCollateralProfile("high");

        // im = 2000e18
        // highest unrealized loss = 0
        // collateral balance = 5000e18
        // collateral balance available = 3000e18

        uint256 collateralBalanceAvailable = accounts.getCollateralBalanceAvailable(accountId, Constants.TOKEN_0);

        assertEq(collateralBalanceAvailable, 3000e18);
    }

    function test_GetCollateralBalanceAvailable_NonSettlementToken() public {
        setCollateralProfile("high");

        uint256 collateralBalanceAvailable = accounts.getCollateralBalanceAvailable(accountId, Constants.TOKEN_1);

        assertEq(collateralBalanceAvailable, Constants.DEFAULT_TOKEN_1_BALANCE);
    }

    function test_GetCollateralBalanceAvailable_Zero() public {
        setCollateralProfile("medium");

        uint256 collateralBalanceAvailable = accounts.getCollateralBalanceAvailable(accountId, Constants.TOKEN_0);

        assertEq(collateralBalanceAvailable, 0);
    }

    function test_GetLiquidationBoosterBalance() public {
        assertEq(
            accounts.getLiquidationBoosterBalance(accountId, Constants.TOKEN_0), Constants.TOKEN_0_LIQUIDATION_BOOSTER
        );
        assertEq(
            accounts.getLiquidationBoosterBalance(accountId, Constants.TOKEN_1), Constants.TOKEN_1_LIQUIDATION_BOOSTER
        );
    }

    function testFuzz_GetCollateralBalanceAvailable_NoSettlementToken() public {
        accounts.changeAccountBalance(
            accountId,
            MockAccountStorage.CollateralBalance({
                token: Constants.TOKEN_UNKNOWN,
                balance: 1e18,
                liquidationBoosterBalance: 0
            })
        );

        uint256 collateralBalanceAvailable = accounts.getCollateralBalanceAvailable(accountId, Constants.TOKEN_UNKNOWN);

        assertEq(collateralBalanceAvailable, 1e18);
    }

    function test_ComputeLMAndUnrealizedLossFromExposures() public {
        uint256 length = 3;
        Account.Exposure[] memory exposures = new Account.Exposure[](length);
        
        uint256 expectedUnrealizedLoss;
        for (uint256 i = 0; i < 3; i += 1) {
            exposures[i] = Account.Exposure({
                productId: 1,
                marketId: (i % 2 == 0) ? 10 : 11,
                annualizedNotional: int256(i * 100),
                unrealizedLoss: i * 50
            });

            expectedUnrealizedLoss += exposures[i].unrealizedLoss;
        } 

        (uint256 liquidationMarginRequirement, uint256 unrealizedLoss) = accounts.computeLMAndUnrealizedLossFromExposures(exposures);
        assertEq(liquidationMarginRequirement, 300);
        assertEq(unrealizedLoss, expectedUnrealizedLoss);
    }


    function test_ComputeLMAndHighestUnrealizedLossFromLowerAndUpperExposures() public {
        uint256 length = 3;
        Account.Exposure[] memory lowerExposures = new Account.Exposure[](length);
        Account.Exposure[] memory upperExposures = new Account.Exposure[](length);

        uint256 expectedUnrealizedLoss;
        uint256 expectedLiquidationMarginRequirement;
        for (uint256 i = 0; i < length; i += 1) {
            lowerExposures[i] = Account.Exposure({
                productId: 1,
                marketId: (i % 2 == 0) ? 10 : 11,
                annualizedNotional: int256(i * 1000),
                unrealizedLoss: i * 500
            });

            upperExposures[i] = Account.Exposure({
                productId: 1,
                marketId: (i % 2 == 0) ? 10 : 11,
                annualizedNotional: int256(i * 100),
                unrealizedLoss: i * 50
            });

            // note, in here we're only taking into account lower exposures because they pose the highest risk
            expectedUnrealizedLoss += lowerExposures[i].unrealizedLoss;
            // in here we're assuming the risk parameter is 1, hence lm = annualized notional * 1 = annualized notional
            expectedLiquidationMarginRequirement += lowerExposures[i].annualizedNotional.toUint();
        }

        (uint256 liquidationMarginRequirement, uint256 highestUnrealizedLoss) = accounts.computeLMAndHighestUnrealizedLossFromLowerAndUpperExposures(lowerExposures, upperExposures);
        assertEq(liquidationMarginRequirement, expectedLiquidationMarginRequirement);
        assertEq(highestUnrealizedLoss, expectedUnrealizedLoss);
    }

    function test_ComputeLiquidationMarginRequirement() public {
        int256 annualizedNotional = 1000;
        UD60x18 riskParameter = UD60x18.wrap(2e18);
        uint256 expectedLiquidationMarginRequirement = 2000;
        uint256 liquidationMarginRequirement = accounts.computeLiquidationMarginRequirement(annualizedNotional, riskParameter);
        assertEq(liquidationMarginRequirement, expectedLiquidationMarginRequirement);
    }

    function test_ComputeInitialMarginRequirement() public {
        uint256 liquidaionMarginRequirement = 2000;
        UD60x18 imMultiplier = UD60x18.wrap(2e18);
        uint256 expectedInitialMarginRequirement = 4000;
        uint256 initialMarginRequirement = accounts.computeInitialMarginRequirement(liquidaionMarginRequirement, imMultiplier);
        assertEq(initialMarginRequirement, expectedInitialMarginRequirement);
    }


}

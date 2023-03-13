//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/storage/Account.sol";
import "../test-utils/MockCoreStorage.sol";

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

    function closeAccount(uint128 id) external {
        Account.load(id).closeAccount();
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

    function getAnnualizedProductExposures(uint128 id, uint128 productId) external returns (Account.Exposure[] memory) {
        Account.Data storage account = Account.load(id);
        return account.getAnnualizedProductExposures(productId);
    }

    function getUnrealizedPnL(uint128 id) external view returns (int256) {
        Account.Data storage account = Account.load(id);
        return account.getUnrealizedPnL();
    }

    function getTotalAccountValue(uint128 id) external view returns (int256) {
        Account.Data storage account = Account.load(id);
        return account.getTotalAccountValue();
    }

    function getRiskParameter(uint128 productId, uint128 marketId) external view returns (int256) {
        return Account.getRiskParameter(productId, marketId);
    }

    function getIMMultiplier() external view returns (uint256) {
        return Account.getIMMultiplier();
    }

    function imCheck(uint128 id) external {
        Account.Data storage account = Account.load(id);
        account.imCheck();
    }

    function isIMSatisfied(uint128 id) external returns (bool, uint256) {
        Account.Data storage account = Account.load(id);
        return account.isIMSatisfied();
    }

    function isLiquidatable(uint128 id) external returns (bool, uint256, uint256) {
        Account.Data storage account = Account.load(id);
        return account.isLiquidatable();
    }

    function getMarginRequirements(uint128 id) external returns (uint256, uint256) {
        Account.Data storage account = Account.load(id);
        return account.getMarginRequirements();
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
        accounts.changeAccountBalance(accountId, MockAccountStorage.CollateralBalance({token: Constants.TOKEN_0, balance: balance}));
    }

    function test_Exists() public {
        bytes32 slot = accounts.exists(accountId);

        assertEq(slot, accountSlot);
    }

    function test_revertWhen_AccountDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 0));

        accounts.exists(0);
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

    function testFuzz_revertWhen_LoadAccountAndValidateOwnership(address randomUser) public {
        vm.assume(randomUser != Constants.ALICE);

        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, accountId, randomUser));
        accounts.loadAccountAndValidateOwnership(accountId, randomUser);
    }

    function test_CloseAccount() public {
        accounts.closeAccount(accountId);
    }

    function test_GetAnnualizedProductExposures() public {
        Account.Exposure[] memory exposures = accounts.getAnnualizedProductExposures(accountId, 1);

        assertEq(exposures.length, 2);

        assertEq(exposures[0].marketId, 10);
        assertEq(exposures[0].filled, 100e18);
        assertEq(exposures[0].unfilledLong, 200e18);
        assertEq(exposures[0].unfilledShort, -200e18);

        assertEq(exposures[1].marketId, 11);
        assertEq(exposures[1].filled, 200e18);
        assertEq(exposures[1].unfilledLong, 300e18);
        assertEq(exposures[1].unfilledShort, -400e18);
    }

    function test_GetUnrealizedPnL() public {
        int256 uPnL = accounts.getUnrealizedPnL(accountId);

        assertEq(uPnL, -100e18);
    }

    function test_GetTotalAccountValue() public {
        int256 totalAccountValue = accounts.getTotalAccountValue(accountId);

        assertEq(totalAccountValue, 400e18);
    }

    function test_GetRiskParameter() public {
        int256 riskParameter = accounts.getRiskParameter(1, 10);

        assertEq(riskParameter, 1e18);
    }

    function test_GetIMMultiplier() public {
        uint256 imMultiplier = accounts.getIMMultiplier();

        assertEq(imMultiplier, 2e18);
    }

    function test_GetMarginRequirements() public {
        (uint256 im, uint256 lm) = accounts.getMarginRequirements(accountId);

        assertEq(lm, 900e18);
        assertEq(im, 1800e18);
    }

    function test_IsLiquidatable_True() public {
        setCollateralProfile("low");

        (bool liquidatable, uint256 im, uint256 lm) = accounts.isLiquidatable(accountId);

        assertEq(liquidatable, true);
        assertEq(lm, 900e18);
        assertEq(im, 1800e18);
    }

    function test_IsLiquidatable_False() public {
        setCollateralProfile("medium");

        (bool liquidatable, uint256 im, uint256 lm) = accounts.isLiquidatable(accountId);

        assertEq(liquidatable, false);
        assertEq(lm, 900e18);
        assertEq(im, 1800e18);
    }

    function test_IsIMSatisfied_False() public {
        setCollateralProfile("medium");

        (bool imSatisfied, uint256 im) = accounts.isIMSatisfied(accountId);

        assertEq(imSatisfied, false);
        assertEq(im, 1800e18);
    }

    function test_IsIMSatisfied_True() public {
        setCollateralProfile("high");

        (bool imSatisfied, uint256 im) = accounts.isIMSatisfied(accountId);

        assertEq(imSatisfied, true);
        assertEq(im, 1800e18);
    }

    function test_revertWhen_ImCheck_False() public {
        setCollateralProfile("medium");

        vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, accountId));
        accounts.imCheck(accountId);
    }

    function test_ImCheck() public {
        setCollateralProfile("high");

        accounts.imCheck(accountId);
    }

    function test_GetCollateralBalanceAvailable_Positive() public {
        setCollateralProfile("high");

        uint256 collateralBalanceAvailable = accounts.getCollateralBalanceAvailable(accountId, Constants.TOKEN_0);

        assertEq(collateralBalanceAvailable, 3100e18);
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

    function testFuzz_GetCollateralBalanceAvailable_NoSettlementToken(address otherToken) public {
        vm.assume(otherToken != Constants.TOKEN_0);
        vm.assume(otherToken != Constants.TOKEN_1);

        accounts.changeAccountBalance(accountId, MockAccountStorage.CollateralBalance({token: otherToken, balance: 1e18}));

        uint256 collateralBalanceAvailable = accounts.getCollateralBalanceAvailable(accountId, otherToken);

        assertEq(collateralBalanceAvailable, 1e18);
    }
}

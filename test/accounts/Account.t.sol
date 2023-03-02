//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/core/storage/Account.sol";

contract ExposedAccounts {
    using Account for Account.Data;
    using SetUtil for SetUtil.UintSet;

    // Mock functions
    function setSettlementToken(uint128 id, address settlementToken) external {
        Account.Data storage account = Account.load(id);
        account.settlementToken = settlementToken;
    }

    function setCollateralBalance(uint128 id, address token, uint256 balanceD18) external {
        Account.Data storage account = Account.load(id);
        account.collaterals[token].balanceD18 = balanceD18;
    }

    function addProduct(uint128 id, uint128 productId) external {
        Account.Data storage account = Account.load(id);
        account.activeProducts.add(productId);
    }

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

    function getCollateralBalance(uint128 id, address collateralType) external view returns (uint256) {
        Account.Data storage account = Account.load(id);
        return account.getCollateralBalance(collateralType);
    }

    function getCollateralBalanceAvailable(uint128 id, address collateralType) external view returns (uint256) {
        Account.Data storage account = Account.load(id);
        return account.getCollateralBalanceAvailable(collateralType);
    }

    function loadAccountAndValidateOwnership(uint128 id, address senderAddress) external view returns (bytes32 s) {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(id, senderAddress);
        assembly {
            s := account.slot
        }
    }

    function getAnnualizedProductExposures(uint128 id, uint128 productId) external view returns (Account.Exposure[] memory) {
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

    function imCheck(uint128 id) external view {
        Account.Data storage account = Account.load(id);
        account.imCheck();
    }

    function isIMSatisfied(uint128 id) external view returns (bool, uint256) {
        Account.Data storage account = Account.load(id);
        return account.isIMSatisfied();
    }

    function isLiquidatable(uint128 id) external view returns (bool, uint256, uint256) {
        Account.Data storage account = Account.load(id);
        return account.isLiquidatable();
    }

    function getMarginRequirements(uint128 id) external view returns (uint256, uint256) {
        Account.Data storage account = Account.load(id);
        return account.getMarginRequirements();
    }
}

contract AccountTest is Test {
    ExposedAccounts internal accounts;

    address internal token = vm.addr(1);
    address internal owner = vm.addr(3);

    uint128 internal constant accountId = 100;
    bytes32 internal constant accountSlot = keccak256(abi.encode("xyz.voltz.Account", accountId));

    address internal mockProductAddress1 = vm.addr(4);
    address internal mockProductAddress2 = vm.addr(5);

    function setUp() public {
        accounts = new ExposedAccounts();

        accounts.create(accountId, owner);
        accounts.setSettlementToken(accountId, token);

        accounts.setCollateralBalance(accountId, token, 350e18);

        setupProducts();
        setupRiskConfigurations();
        setupProtocolRiskConfigurations();
    }

    function setupProducts() public {
        // Add Product with product ID 1 and address mockProductAddress1
        accounts.addProduct(accountId, 1);
        bytes32 productSlot = keccak256(abi.encode("xyz.voltz.Product", 1));
        assembly {
            productSlot := add(productSlot, 1)
        }
        vm.store(address(accounts), productSlot, bytes32(uint256(uint160(mockProductAddress1))));

        // Mock account exposures to product ID 1 and markets IDs 10, 11
        Account.Exposure[] memory mockExposures = new Account.Exposure[](2);
        mockExposures[0] = Account.Exposure({ marketId: 10, filled: 100e18, unfilledLong: 200e18, unfilledShort: -200e18 });

        mockExposures[1] = Account.Exposure({ marketId: 11, filled: 200e18, unfilledLong: 300e18, unfilledShort: -400e18 });

        vm.mockCall(
            mockProductAddress1, abi.encodeWithSelector(IProduct.getAccountAnnualizedExposures.selector), abi.encode(mockExposures)
        );

        // Mock account closure to product ID 1
        vm.mockCall(mockProductAddress1, abi.encodeWithSelector(IProduct.closeAccount.selector), abi.encode());

        // Mock account uPnL in product ID 1
        vm.mockCall(mockProductAddress1, abi.encodeWithSelector(IProduct.getAccountUnrealizedPnL.selector), abi.encode(100e18));

        // Add Product with product ID 2 and address mockProductAddress1
        accounts.addProduct(accountId, 2);
        productSlot = keccak256(abi.encode("xyz.voltz.Product", 2));
        assembly {
            productSlot := add(productSlot, 1)
        }
        vm.store(address(accounts), productSlot, bytes32(uint256(uint160(mockProductAddress2))));

        // Mock account exposures to product ID 2 and markets IDs 20
        mockExposures = new Account.Exposure[](1);
        mockExposures[0] = Account.Exposure({ marketId: 20, filled: -50e18, unfilledLong: 150e18, unfilledShort: -150e18 });

        vm.mockCall(
            mockProductAddress2, abi.encodeWithSelector(IProduct.getAccountAnnualizedExposures.selector), abi.encode(mockExposures)
        );

        // Mock account closure to product ID 2
        vm.mockCall(mockProductAddress2, abi.encodeWithSelector(IProduct.closeAccount.selector), abi.encode());

        // Mock account uPnL in product ID 2
        vm.mockCall(mockProductAddress2, abi.encodeWithSelector(IProduct.getAccountUnrealizedPnL.selector), abi.encode(-200e18));
    }

    function setupRiskConfigurations() public {
        // Mock risk parameter for product ID 1 and market ID 10
        bytes32 slot = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 1, 10));
        assembly {
            slot := add(slot, 1)
        }
        vm.store(address(accounts), slot, bytes32(abi.encode(1e18)));

        // Mock risk parameter for product ID 1 and market ID 11
        slot = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 1, 11));
        assembly {
            slot := add(slot, 1)
        }
        vm.store(address(accounts), slot, bytes32(abi.encode(1e18)));

        // Mock risk parameter for product ID 2 and market ID 20
        slot = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 2, 20));
        assembly {
            slot := add(slot, 1)
        }
        vm.store(address(accounts), slot, bytes32(abi.encode(1e18)));
    }

    function setupProtocolRiskConfigurations() public {
        bytes32 slot = keccak256(abi.encode("xyz.voltz.ProtocolRiskConfiguration"));
        vm.store(address(accounts), slot, bytes32(abi.encode(2e18)));
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
        uint256 collateralBalanceD18 = accounts.getCollateralBalance(accountId, token);
        assertEq(collateralBalanceD18, 350e18);
    }

    function testFuzz_GetCollateralBalance_NoCollateral(address otherToken) public {
        vm.assume(otherToken != token);

        uint256 collateralBalanceD18 = accounts.getCollateralBalance(accountId, otherToken);
        assertEq(collateralBalanceD18, 0);
    }

    function test_LoadAccountAndValidateOwnership() public {
        vm.prank(owner);
        bytes32 slot = accounts.loadAccountAndValidateOwnership(accountId, owner);

        assertEq(slot, accountSlot);
    }

    function testFuzz_revertWhen_LoadAccountAndValidateOwnership(address randomUser) public {
        vm.assume(randomUser != owner);

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

        assertEq(totalAccountValue, 250e18);
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

    function testFuzz_IsLiquidatable_True(uint256 balance) public {
        vm.assume(balance < 1000e18);
        accounts.setCollateralBalance(accountId, token, balance);

        (bool liquidatable, uint256 im, uint256 lm) = accounts.isLiquidatable(accountId);

        assertEq(liquidatable, true);
        assertEq(lm, 900e18);
        assertEq(im, 1800e18);
    }

    function testFuzz_IsLiquidatable_False(uint256 balance) public {
        balance = bound(balance, 1000e18, 1000e27);
        accounts.setCollateralBalance(accountId, token, balance);

        (bool liquidatable, uint256 im, uint256 lm) = accounts.isLiquidatable(accountId);

        assertEq(liquidatable, false);
        assertEq(lm, 900e18);
        assertEq(im, 1800e18);
    }

    function testFuzz_IsIMSatisfied_False(uint256 balance) public {
        vm.assume(balance < 1900e18);
        accounts.setCollateralBalance(accountId, token, balance);

        (bool imSatisfied, uint256 im) = accounts.isIMSatisfied(accountId);

        assertEq(imSatisfied, false);
        assertEq(im, 1800e18);
    }

    function testFuzz_IsIMSatisfied_True(uint256 balance) public {
        balance = bound(balance, 1900e18, 1000e27);
        accounts.setCollateralBalance(accountId, token, balance);

        (bool imSatisfied, uint256 im) = accounts.isIMSatisfied(accountId);

        assertEq(imSatisfied, true);
        assertEq(im, 1800e18);
    }

    function testFuzz_revertWhen_ImCheck_False(uint256 balance) public {
        vm.assume(balance < 1900e18);
        accounts.setCollateralBalance(accountId, token, balance);

        vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, accountId));

        accounts.imCheck(accountId);
    }

    function testFuzz_ImCheck(uint256 balance) public {
        balance = bound(balance, 1900e18, 1000e27);
        accounts.setCollateralBalance(accountId, token, balance);

        accounts.imCheck(accountId);
    }

    function testFuzz_GetCollateralBalanceAvailable_Positive(uint256 balance) public {
        balance = bound(balance, 1900e18, 1000e27);
        accounts.setCollateralBalance(accountId, token, balance);

        uint256 collateralBalanceAvailableD18 = accounts.getCollateralBalanceAvailable(accountId, token);

        assertEq(collateralBalanceAvailableD18, balance - 1900e18);
    }

    function testFuzz_GetCollateralBalanceAvailable_Zero(uint256 balance) public {
        vm.assume(balance <= 1900e18);
        accounts.setCollateralBalance(accountId, token, balance);

        uint256 collateralBalanceAvailableD18 = accounts.getCollateralBalanceAvailable(accountId, token);

        assertEq(collateralBalanceAvailableD18, 0);
    }

    function testFuzz_GetCollateralBalanceAvailable_NoSettlementToken(address otherToken) public {
        vm.assume(otherToken != token);

        accounts.setCollateralBalance(accountId, otherToken, 100e18);

        uint256 collateralBalanceAvailableD18 = accounts.getCollateralBalanceAvailable(accountId, otherToken);

        assertEq(collateralBalanceAvailableD18, 100e18);
    }
}

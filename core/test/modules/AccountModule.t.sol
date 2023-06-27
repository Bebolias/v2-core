/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/AccountModule.sol";
import "../../src/storage/AccountRBAC.sol";
import "../../src/storage/AccessPassConfiguration.sol";
import "../../src/interfaces/external/IAccessPassNFT.sol";
import "../test-utils/MockCoreStorage.sol";

contract EnhancedAccountModuleTest is AccountModule, CoreState {}

contract AccountModuleTest is Test {
    event AccountCreated(uint128 indexed accountId, address indexed owner, address indexed trigger, uint256 blockTimestamp);
    event PermissionGranted(
        uint128 indexed accountId,
        bytes32 indexed permission,
        address indexed user,
        address sender,
        uint256 blockTimestamp
    );
    event PermissionRevoked(
        uint128 indexed accountId,
        bytes32 indexed permission,
        address indexed user,
        address sender,
        uint256 blockTimestamp
    );

    EnhancedAccountModuleTest internal accountModule;
    address internal proxyAddress = vm.addr(1);

    bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";

    address internal owner = vm.addr(2);

    function setUp() public {
        accountModule = new EnhancedAccountModuleTest();

        vm.store(
            address(accountModule),
            keccak256(abi.encode("xyz.voltz.OwnableStorage")),
            bytes32(abi.encode(owner))
        );

        mockAssociatedSystem();
    }

    function mockAssociatedSystem() internal {
        bytes32 slot = keccak256(abi.encode("xyz.voltz.AssociatedSystem", bytes32("accountNFT")));

        // Mock proxy
        vm.store(address(accountModule), slot, bytes32(abi.encode(proxyAddress)));
    }

    function test_GetAccountTokenAddress() public {
        assertEq(accountModule.getAccountTokenAddress(), proxyAddress);
    }

    function test_CreateAccount() public {
        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        // Expect AccountCreated event
        vm.expectEmit(true, true, true, true, address(accountModule));
        emit AccountCreated(100, address(this), address(this), block.timestamp);

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;

        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );

        accountModule.createAccount(100, address(this));
    }

    function test_RevertWhen_CreateAccount_Global_Deny_All() public {
        vm.prank(owner);
        accountModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );

        accountModule.createAccount(100, address(this));
    }

//test_RevertWhen_RevokePermission_Global_Deny_All

    function test_RevertWhen_CreateAccount_UnmockedMint() public {
        vm.expectRevert();
        accountModule.createAccount(100, address(this));
    }

    function test_GetAccountPermissions_AccountCreator() public {
        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);

        assertEq(accountModule.getAccountOwner(100), address(this));
        assertEq(accountPerms.length, 0);
    }

    function test_GrantPermission() public {
        address authorizedAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        vm.expectEmit(true, true, true, true, address(accountModule));
        emit PermissionGranted(100, AccountRBAC._ADMIN_PERMISSION, authorizedAddress, address(this), block.timestamp);

        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, authorizedAddress);

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 1);
        assertEq(accountPerms[0].user, authorizedAddress);
        assertEq(accountPerms[0].permissions.length, 1);
        assertEq(accountPerms[0].permissions[0], AccountRBAC._ADMIN_PERMISSION);
    }

    function test_RevertWhen_GrantPermission_Global_Deny_All() public {
        vm.prank(owner);
        accountModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );

        address authorizedAddress = address(1);
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, authorizedAddress);
    }

    function test_RevertWhen_GrantPermission() public {
        address unauthorizedAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        vm.prank(unauthorizedAddress);
        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, unauthorizedAddress));
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, unauthorizedAddress);
    }

    function test_RevertWhen_GrantPermissionFromAdmin() public {
        address adminAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, adminAddress);
        assertEq(accountModule.hasPermission(100, AccountRBAC._ADMIN_PERMISSION, adminAddress), true);

        vm.prank(adminAddress);
        address randomAddress = address(2);
        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, adminAddress));
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, randomAddress);
    }

    function test_RevokePermission() public {
        address revokedAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);

        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress);
        accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 1);

        vm.expectEmit(true, true, true, true, address(accountModule));
        emit PermissionRevoked(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress, address(this), block.timestamp);

        accountModule.revokePermission(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress);
        accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);
    }

    function test_RevertWhen_RevokePermission_Global_Deny_All() public {
        vm.prank(owner);
        accountModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );
        address revokedAddress = address(1);
        accountModule.revokePermission(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress);
    }

    function test_RevertWhen_RevokeInexistentPermission() public {
        address revokedAddress = address(1);

        vm.assume(revokedAddress != address(this));
        vm.assume(revokedAddress != address(0));

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);

        vm.expectRevert(abi.encodeWithSelector(SetUtil.ValueNotInSet.selector));
        accountModule.revokePermission(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress);

        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accountModule.revokePermission(100, "PER123", revokedAddress);
    }

    function test_RevertWhen_RevokeUnauthorizedPermission() public {
        address revokedAddress = address(1);
        address unauthorizedAddress = address(2);

        vm.assume(revokedAddress != address(this));
        vm.assume(revokedAddress != address(0));

        vm.assume(unauthorizedAddress != address(this));
        vm.assume(unauthorizedAddress != revokedAddress);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress);

        vm.prank(unauthorizedAddress);
        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, unauthorizedAddress));
        accountModule.revokePermission(100, AccountRBAC._ADMIN_PERMISSION, revokedAddress);
    }

    function test_RevertWhen_RevokePermissionFromAdmin() public {
        address adminAddress = address(1);
        address otherAdminAddress = address(2);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, adminAddress);
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, otherAdminAddress);
        assertEq(accountModule.hasPermission(100, AccountRBAC._ADMIN_PERMISSION, adminAddress), true);
        assertEq(accountModule.hasPermission(100, AccountRBAC._ADMIN_PERMISSION, otherAdminAddress), true);

        vm.prank(adminAddress);
        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, adminAddress));
        accountModule.revokePermission(100, AccountRBAC._ADMIN_PERMISSION, otherAdminAddress);
    }

    function test_RenouncePermission() public {
        address renouncedAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );
        accountModule.createAccount(100, address(this));

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);

        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, renouncedAddress);
        accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 1);

        vm.expectEmit(true, true, true, true, address(accountModule));
        emit PermissionRevoked(100, AccountRBAC._ADMIN_PERMISSION, renouncedAddress, renouncedAddress, block.timestamp);

        vm.prank(renouncedAddress);
        accountModule.renouncePermission(100, AccountRBAC._ADMIN_PERMISSION);
        accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);
    }

    function test_RevertWhen_RenouncePermission_Global_Deny_All() public {
        vm.prank(owner);
        accountModule.setFeatureFlagDenyAll(_GLOBAL_FEATURE_FLAG, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                FeatureFlag.FeatureUnavailable.selector, _GLOBAL_FEATURE_FLAG
            )
        );

        accountModule.renouncePermission(100, AccountRBAC._ADMIN_PERMISSION);
    }

    function test_RevertWhen_RenounceInexistentPermission() public {
        address renouncedAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, address(this)),
            abi.encode(1)
        );

        accountModule.createAccount(100, address(this));

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);

        vm.prank(renouncedAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountModule.PermissionNotGranted.selector, 100, AccountRBAC._ADMIN_PERMISSION, renouncedAddress
            )
        );
        accountModule.renouncePermission(100, AccountRBAC._ADMIN_PERMISSION);
    }

    function test_NotifyAccountTransfer() public {
        address to = vm.addr(2);

        vm.prank(proxyAddress);
        accountModule.notifyAccountTransfer(to, 100);

        assertEq(accountModule.getAccountOwner(100), to);
    }

    function test_RevertWhen_NotifyAccountTransfer_NoTokenAccount() public {
        address otherAddress = address(1);

        vm.prank(otherAddress);

        vm.expectRevert(abi.encodeWithSelector(IAccountModule.OnlyAccountTokenProxy.selector, otherAddress));
        accountModule.notifyAccountTransfer(vm.addr(2), 100);
    }

    function test_ResetPermissionsNotifyAccountTransfer() public {
        // duplicate logic, consider simplifying
        address to = vm.addr(2);
        address randomAddress = address(1);
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.prank(randomAddress);
        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, randomAddress),
            abi.encode(1)
        );
        accountModule.createAccount(100, randomAddress);
        vm.prank(randomAddress);
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, vm.addr(3));

        AccountModule.AccountPermissions[] memory accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 1);

        vm.prank(proxyAddress);

        accountModule.notifyAccountTransfer(to, 100);
        accountPerms = accountModule.getAccountPermissions(100);
        assertEq(accountPerms.length, 0);
    }

    function test_GetAccountOwner() public {
        address randomAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        vm.prank(randomAddress);

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;

        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, randomAddress),
            abi.encode(1)
        );

        accountModule.createAccount(100, randomAddress);

        assertEq(accountModule.getAccountOwner(100), randomAddress);
    }

    function test_IsAuthorized_True() public {
        address randomAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, randomAddress),
            abi.encode(1)
        );

        vm.prank(randomAddress);
        accountModule.createAccount(100, randomAddress);

        assertEq(accountModule.isAuthorized(100, AccountRBAC._ADMIN_PERMISSION, randomAddress), true);
    }

    function test_IsAuthorized_False() public {
        address randomAddress = address(1);
        address otherAddress = address(2);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, randomAddress),
            abi.encode(1)
        );

        vm.prank(randomAddress);
        accountModule.createAccount(100, randomAddress);

        assertEq(accountModule.isAuthorized(100, AccountRBAC._ADMIN_PERMISSION, otherAddress), false);
    }

    function test_HasPermission_True() public {
        address randomAddress = address(1);
        address otherAddress = address(2);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        vm.prank(randomAddress);

        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, randomAddress),
            abi.encode(1)
        );

        accountModule.createAccount(100, randomAddress);
        vm.prank(randomAddress);
        accountModule.grantPermission(100, AccountRBAC._ADMIN_PERMISSION, otherAddress);

        assertEq(accountModule.hasPermission(100, AccountRBAC._ADMIN_PERMISSION, otherAddress), true);
    }

    function test_HasPermission_False() public {
        address randomAddress = address(1);

        vm.mockCall(
            proxyAddress, abi.encodeWithSelector(INftModule.safeMint.selector, address(this), 100, ""), abi.encode()
        );

        vm.prank(randomAddress);
        address accessPassNFTAddress = AccessPassConfiguration.load().accessPassNFTAddress;
        vm.mockCall(
            accessPassNFTAddress,
            0,
            abi.encodeWithSelector(IAccessPassNFT.balanceOf.selector, randomAddress),
            abi.encode(1)
        );
        accountModule.createAccount(100, randomAddress);

        assertEq(accountModule.hasPermission(100, AccountRBAC._ADMIN_PERMISSION, randomAddress), false);
    }
}

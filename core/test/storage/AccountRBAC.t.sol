pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/AccountRBAC.sol";

contract ExposedAccountRBAC {
    using AccountRBAC for AccountRBAC.Data;
    using SetUtil for SetUtil.Bytes32Set;
    using SetUtil for SetUtil.AddressSet;

    AccountRBAC.Data internal item;

    constructor(address owner) {
        item.owner = owner;
    }

    // Mock functions
    function getOwner() external view returns (address) {
        return item.owner;
    }

    // Exposed functions
    function setOwner(address owner) external {
        AccountRBAC.setOwner(item, owner);
    }

    function getPermissions(address target) external view returns (bytes32[] memory) {
        return item.permissions[target].values();
    }

    function getPermissionAddresses() external view returns (address[] memory) {
        return item.permissionAddresses.values();
    }

    function checkPermissionIsValid(bytes32 permission) external pure {
        AccountRBAC.checkPermissionIsValid(permission);
    }

    function grantPermission(bytes32 permission, address target) external {
        item.grantPermission(permission, target);
    }

    function revokePermission(bytes32 permission, address target) external {
        item.revokePermission(permission, target);
    }

    function revokeAllPermissions(address target) external {
        item.revokeAllPermissions(target);
    }

    function hasPermission(bytes32 permission, address target) external view returns (bool) {
        return item.hasPermission(permission, target);
    }

    function authorized(bytes32 permission, address target) external view returns (bool) {
        return AccountRBAC.authorized(item, permission, target);
    }
}

contract AccountRBACTest is Test {
    function test_Initiation() public {
        address owner = address(1);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        assertEq(accountRBAC.getOwner(), owner);
    }

    function test_SetOwner() public {
        address owner = address(1);
        address newOwner = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        accountRBAC.setOwner(newOwner);

        assertEq(accountRBAC.getOwner(), newOwner);
    }

    function test_Authorized_True() public {
        address owner = address(1);
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        bool authorized = accountRBAC.authorized("ADMIN", owner);

        assertEq(authorized, true);
    }

    function test_Authorized_False() public {
        address owner = address(1);
        address target = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        bool authorized = accountRBAC.authorized("ADMIN", target);

        assertEq(authorized, false);
    }

    function test_RevertWhen_InvalidAuthorized() public {
        address owner = address(1);
        address target = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accountRBAC.authorized("PER123", target);
    }

    function test_Authorized_SetOwner() public {
        address firstOwner = address(1);
        address secondOwner = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(firstOwner);
        assertEq(accountRBAC.authorized("ADMIN", firstOwner), true);
        assertEq(accountRBAC.authorized("ADMIN", secondOwner), false);

        accountRBAC.setOwner(secondOwner);
        assertEq(accountRBAC.authorized("ADMIN", firstOwner), false);
        assertEq(accountRBAC.authorized("ADMIN", secondOwner), true);
    }

    function test_ValidPermission() public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));
        accountRBAC.checkPermissionIsValid("ADMIN");
    }

    function test_RevertWhen_InvalidPermission() public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));
        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accountRBAC.checkPermissionIsValid("PER123");
    }

    function test_RevertWhen_HasPermission() public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));
        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accountRBAC.hasPermission("PER123", address(2));
    }

    function test_GrantPermission() public {
        address randomAddress = address(1);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));
        accountRBAC.grantPermission("ADMIN", randomAddress);

        bytes32[] memory permissions = accountRBAC.getPermissions(randomAddress);
        assertEq(permissions.length, 1);
        assertEq(permissions[0], bytes32("ADMIN"));

        address[] memory permissionAddresses = accountRBAC.getPermissionAddresses();
        assertEq(permissionAddresses.length, 1);
        assertEq(permissionAddresses[0], randomAddress);

        assertEq(accountRBAC.hasPermission("ADMIN", randomAddress), true);
    }

    function test_RevertWhen_GrantPermission() public {
        address randomAddress = address(1);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));

        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accountRBAC.grantPermission("PER123", randomAddress);

        vm.expectRevert(abi.encodeWithSelector(AddressError.ZeroAddress.selector));
        accountRBAC.grantPermission("ADMIN", address(0));
    }

    function test_RevokePermission() public {
        address randomAddress = address(1);
        address randomAddress2 = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));

        accountRBAC.grantPermission("ADMIN", randomAddress);
        accountRBAC.grantPermission("ADMIN", randomAddress2);

        accountRBAC.revokePermission("ADMIN", randomAddress);

        bytes32[] memory permissions = accountRBAC.getPermissions(randomAddress);
        assertEq(permissions.length, 0);

        address[] memory permissionAddresses = accountRBAC.getPermissionAddresses();
        assertEq(permissionAddresses.length, 1);
        assertEq(permissionAddresses[0], randomAddress2);
    }

    function test_RevertWhen_RevokePermission() public {
        address randomAddress = address(1);
        address randomAddress2 = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));

        accountRBAC.grantPermission("ADMIN", randomAddress2);

        vm.expectRevert(abi.encodeWithSelector(SetUtil.ValueNotInSet.selector));
        accountRBAC.revokePermission("ADMIN", randomAddress);

        vm.expectRevert(abi.encodeWithSelector(AccountRBAC.InvalidPermission.selector, bytes32("PER123")));
        accountRBAC.revokePermission("PER123", randomAddress2);
    }

    function test_RevokeAllPermissions() public {
        address randomAddress = address(1);
        address randomAddress2 = address(2);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(address(1));

        accountRBAC.grantPermission("ADMIN", randomAddress);
        accountRBAC.grantPermission("ADMIN", randomAddress2);

        accountRBAC.revokeAllPermissions(randomAddress);

        bytes32[] memory permissions = accountRBAC.getPermissions(randomAddress);
        assertEq(permissions.length, 0);

        address[] memory permissionAddresses = accountRBAC.getPermissionAddresses();
        assertEq(permissionAddresses.length, 1);
        assertEq(permissionAddresses[0], randomAddress2);

        address randomAddress3 = address(3);
        accountRBAC.revokeAllPermissions(randomAddress3);

        permissionAddresses = accountRBAC.getPermissionAddresses();
        assertEq(permissionAddresses.length, 1);
        assertEq(permissionAddresses[0], randomAddress2);
    }
}

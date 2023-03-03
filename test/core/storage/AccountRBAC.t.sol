//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/storage/AccountRBAC.sol";

contract ExposedAccountRBAC {
    using AccountRBAC for AccountRBAC.Data;

    AccountRBAC.Data internal item;

    constructor(address owner) {
        item = AccountRBAC.Data({ owner: owner });
    }

    // Mock functions
    function get() external view returns (AccountRBAC.Data memory) {
        return item;
    }

    // Exposed functions
    function setOwner(address owner) external {
        item.owner = owner;
    }

    function authorized(address target) external view returns (bool) {
        return target == item.owner;
    }
}

contract AccountRBACTest is Test {
    function test_SetOwner() public {
        address owner = vm.addr(1);
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        address newOwner = vm.addr(2);
        accountRBAC.setOwner(newOwner);

        assertEq(accountRBAC.get().owner, newOwner);
    }

    function test_Authorized_True() public {
        address owner = vm.addr(1);
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        bool authorized = accountRBAC.authorized(owner);

        assertEq(authorized, true);
    }

    function test_Authorized_False() public {
        address owner = vm.addr(1);
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        address target = vm.addr(2);
        bool authorized = accountRBAC.authorized(target);

        assertEq(authorized, false);
    }

    function testFuzz_SetOwner(address owner, address newOwner) public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);
        accountRBAC.setOwner(newOwner);

        assertEq(accountRBAC.get().owner, newOwner);
    }

    function testFuzz_Authorized_False(address owner, address target) public {
        vm.assume(owner != target);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        bool authorized = accountRBAC.authorized(target);
        assertEq(authorized, false);
    }
}

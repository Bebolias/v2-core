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
        AccountRBAC.setOwner(item, owner);
    }

    function authorized(address target) external view returns (bool) {
        return AccountRBAC.authorized(item, target);
    }
}

contract AccountRBACTest is Test {
    function testFuzz_Initiation(address owner) public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        assertEq(accountRBAC.get().owner, owner);
    }

    function testFuzz_SetOwner(address owner, address newOwner) public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        accountRBAC.setOwner(newOwner);

        assertEq(accountRBAC.get().owner, newOwner);
    }

    function testFuzz_Authorized_True(address owner) public {
        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        bool authorized = accountRBAC.authorized(owner);

        assertEq(authorized, true);
    }

    function testFuzz_Authorized_False(address owner, address target) public {
        vm.assume(owner != target);

        ExposedAccountRBAC accountRBAC = new ExposedAccountRBAC(owner);

        bool authorized = accountRBAC.authorized(target);

        assertEq(authorized, false);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/modules/AccountModule.sol";

contract AccountModuleTest is Test {
    event AccountCreated(uint128 indexed accountId, address indexed owner);

    AccountModule internal accountModule;
    address internal proxyAddress = vm.addr(1);

    function setUp() public {
        accountModule = new AccountModule();

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
        vm.mockCall(proxyAddress, abi.encodeWithSelector(INFT.safeMint.selector, address(this), 100, ""), abi.encode());

        // Expect AccountCreated event
        vm.expectEmit(true, true, true, true, address(accountModule));
        emit AccountCreated(100, address(this));

        accountModule.createAccount(100);
    }

    function test_revertWhen_CreateAccount_UnmockedMint() public {
        vm.expectRevert();
        accountModule.createAccount(100);
    }

    function test_NotifyAccountTransfer() public {
        address to = vm.addr(2);

        vm.prank(proxyAddress);
        accountModule.notifyAccountTransfer(to, 100);

        assertEq(accountModule.getAccountOwner(100), to);
    }

    function testFuzz_revertWhen_NotifyAccountTransfer_NoTokenAccount(address otherAddress) public {
        vm.assume(otherAddress != proxyAddress);

        vm.prank(otherAddress);

        vm.expectRevert(abi.encodeWithSelector(IAccountModule.OnlyAccountTokenProxy.selector, otherAddress));
        accountModule.notifyAccountTransfer(vm.addr(2), 100);
    }

    function testFuzz_GetAccountOwner(address randomAddress) public {
        vm.mockCall(proxyAddress, abi.encodeWithSelector(INFT.safeMint.selector, address(this), 100, ""), abi.encode());

        vm.prank(randomAddress);
        accountModule.createAccount(100);

        assertEq(accountModule.getAccountOwner(100), randomAddress);
    }

    function testFuzz_IsAuthorized_True(address randomAddress) public {
        vm.mockCall(proxyAddress, abi.encodeWithSelector(INFT.safeMint.selector, address(this), 100, ""), abi.encode());

        vm.prank(randomAddress);
        accountModule.createAccount(100);

        assertEq(accountModule.isAuthorized(100, randomAddress), true);
    }

    function testFuzz_IsAuthorized_False(address randomAddress, address otherAddress) public {
        vm.assume(otherAddress != randomAddress);

        vm.mockCall(proxyAddress, abi.encodeWithSelector(INFT.safeMint.selector, address(this), 100, ""), abi.encode());

        vm.prank(randomAddress);
        accountModule.createAccount(100);

        assertEq(accountModule.isAuthorized(100, otherAddress), false);
    }
}

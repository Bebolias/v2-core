// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/modules/AccountTokenModule.sol";

contract AccountTokenModuleTest is Test, IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    AccountTokenModule internal accountTokenModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        accountTokenModule = new AccountTokenModule();

        vm.store(address(accountTokenModule), keccak256(abi.encode("xyz.voltz.OwnableStorage")), bytes32(abi.encode(owner)));

        vm.prank(owner);
        accountTokenModule.initialize("Voltz", "VLTZ", "");
    }

    function test_Transfer() public {
        address user = vm.addr(2);
        uint128 accountId = 100;

        vm.mockCall(
            address(owner), abi.encodeWithSelector(IAccountModule.notifyAccountTransfer.selector, user, accountId), abi.encode()
        );

        vm.prank(owner);
        accountTokenModule.safeMint(user, accountId, "");
    }

    function test_revertWhen_Transfer_UnmockedAccountTransfer() public {
        address user = vm.addr(2);
        uint128 accountId = 100;

        vm.prank(owner);
        vm.expectRevert();
        accountTokenModule.safeMint(user, accountId, "");
    }
}

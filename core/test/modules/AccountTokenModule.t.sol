/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/AccountTokenModule.sol";

contract AccountTokenModuleTest is Test, IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    AccountTokenModule internal accountTokenModule;
    address internal owner = vm.addr(1);

    function setUp() public {
        accountTokenModule = new AccountTokenModule();

        vm.store(
            address(accountTokenModule), keccak256(abi.encode("xyz.voltz.OwnableStorage")), bytes32(abi.encode(owner))
        );

        vm.prank(owner);
        accountTokenModule.initialize("Voltz", "VLTZ", "");
    }

    function test_Transfer() public {
        address user = vm.addr(2);
        uint128 accountId = 100;

        vm.mockCall(
            address(owner),
            abi.encodeWithSelector(IAccountModule.notifyAccountTransfer.selector, user, accountId),
            abi.encode()
        );

        vm.prank(owner);
        accountTokenModule.safeMint(user, accountId, "");
    }

    function test_RevertWhen_Transfer_UnmockedAccountTransfer() public {
        address user = vm.addr(2);
        uint128 accountId = 100;

        vm.prank(owner);
        vm.expectRevert();
        accountTokenModule.safeMint(user, accountId, "");
    }
}

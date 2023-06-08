// https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/PeripheryModule.sol";
import "../test-utils/Constants.sol";

contract ExtendedPeripheryModule is PeripheryModule {
    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }

    function isPeriphery(address p) external returns (bool) {
        return Periphery.isPeriphery(p);
    }

    function load() external returns (bytes32 s) {
        Periphery.Data storage periphery = Periphery.load();
        assembly {
            s := periphery.slot
        }
    }
}

contract PeripheryModuleTest is Test {

    ExtendedPeripheryModule internal peripheryModule;

    function setUp() public {
        peripheryModule = new ExtendedPeripheryModule();
        peripheryModule.setOwner(address(this));
    }

    function test_LoadAtCorrectSlot() public {
        bytes32 peripherySlot = keccak256(abi.encode("xyz.voltz.Periphery"));
        bytes32 slot = peripheryModule.load();
        assertEq(slot, peripherySlot);
    }

    function test_SetPeriphery() public {
        assertTrue(peripheryModule.isPeriphery(address(0)));
        peripheryModule.setPeriphery(address(Constants.PERIPHERY));
        assertTrue(peripheryModule.isPeriphery(Constants.PERIPHERY));
    }

    function test_RevertWhen_SetPeriphery_NotOwner() public {
        assertTrue(peripheryModule.isPeriphery(address(0)));

        vm.prank(Constants.ALICE);

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, Constants.ALICE));
        peripheryModule.setPeriphery(address(Constants.PERIPHERY));
        assertTrue(peripheryModule.isPeriphery(address(0)));
    }
}

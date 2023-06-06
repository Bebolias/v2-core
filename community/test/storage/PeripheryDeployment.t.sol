pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "../../src/storage/PeripheryDeployment.sol";

import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";

contract ExposedPeripheryDeployment {
    using PeripheryDeployment for PeripheryDeployment.Data;

    function load() external pure returns (bytes32 s) {
        PeripheryDeployment.Data storage account = PeripheryDeployment.load();
        assembly {
            s := account.slot
        }
    }

    function set(PeripheryDeployment.Data memory config) external {
      PeripheryDeployment.set(config);
    }

    function deploy(address ownerAddress) external returns (address peripheryProxy) {
      peripheryProxy = PeripheryDeployment.deploy(ownerAddress);
    }

    function getPeripheryRouter() external view returns (address) {
      return PeripheryDeployment.load().peripheryRouter;
    }
}

contract MockPeripheryRouter is OwnerUpgradeModule {}

contract PeripheryDeploymentTest is Test {
    ExposedPeripheryDeployment internal peripheryDeployment;

    bytes32 internal constant peripheryDeploymentSlot = keccak256(abi.encode("xyz.voltz.CommunityPeripheryDeployment"));

    function setUp() public {
        peripheryDeployment = new ExposedPeripheryDeployment();
    }

    function test_load() public {
      bytes32 slot = peripheryDeployment.load();
      assertEq(slot, peripheryDeploymentSlot);
    }

    function test_set() public {
      peripheryDeployment.set(PeripheryDeployment.Data({
        peripheryRouter: address(1)
      }));

      assertEq(peripheryDeployment.getPeripheryRouter(), address(1));
    }

    function test_RevertWhen_NoPeripheryRouter() public {
      vm.expectRevert(abi.encodeWithSelector(PeripheryDeployment.MissingPeripheryRouter.selector));
      peripheryDeployment.set(PeripheryDeployment.Data({
        peripheryRouter: address(0)
      }));
    }

    function test_deploy() public {
      address peripheryRouter = address(new MockPeripheryRouter());
      peripheryDeployment.set(PeripheryDeployment.Data({
        peripheryRouter: peripheryRouter
      }));

      address ownerAddress = address(1234);
      address peripheryProxy = peripheryDeployment.deploy(ownerAddress);
      assert(peripheryProxy != address(0));

      // accept ownership
      vm.prank(ownerAddress);
      Ownable(peripheryProxy).acceptOwnership();

      assertEq(Ownable(peripheryProxy).owner(), ownerAddress);
    }
}

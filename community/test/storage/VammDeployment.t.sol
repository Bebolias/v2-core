pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "../../src/storage/VammDeployment.sol";

import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";

contract ExposedVammDeployment {
    using VammDeployment for VammDeployment.Data;

    function load() external pure returns (bytes32 s) {
        VammDeployment.Data storage account = VammDeployment.load();
        assembly {
            s := account.slot
        }
    }

    function set(VammDeployment.Data memory config) external {
      VammDeployment.set(config);
    }

    function deploy(address ownerAddress) external returns (address vammProxy) {
      vammProxy = VammDeployment.deploy(ownerAddress);
    }

    function getVammRouter() external view returns (address) {
      return VammDeployment.load().vammRouter;
    }
}

contract MockVammRouter is OwnerUpgradeModule {}

contract VammDeploymentTest is Test {
    ExposedVammDeployment internal vammDeployment;

    bytes32 internal constant vammDeploymentSlot = keccak256(abi.encode("xyz.voltz.CommunityVammDeployment"));

    function setUp() public {
        vammDeployment = new ExposedVammDeployment();
    }

    function test_load() public {
      bytes32 slot = vammDeployment.load();
      assertEq(slot, vammDeploymentSlot);
    }

    function test_set() public {
      vammDeployment.set(VammDeployment.Data({
        vammRouter: address(1)
      }));

      assertEq(vammDeployment.getVammRouter(), address(1));
    }

    function test_RevertWhen_NoVammRouter() public {
      vm.expectRevert(abi.encodeWithSelector(VammDeployment.MissingVammRouter.selector));
      vammDeployment.set(VammDeployment.Data({
        vammRouter: address(0)
      }));
    }

    function test_deploy() public {
      address vammRouter = address(new MockVammRouter());
      vammDeployment.set(VammDeployment.Data({
        vammRouter: vammRouter
      }));

      address ownerAddress = address(1234);
      address vammProxy = vammDeployment.deploy(ownerAddress);
      assert(vammProxy != address(0));

      // accept ownership
      vm.prank(ownerAddress);
      Ownable(vammProxy).acceptOwnership();

      assertEq(Ownable(vammProxy).owner(), ownerAddress);
    }
}

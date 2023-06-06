pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "../../src/storage/DatedIrsDeployment.sol";

import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";

contract ExposedDatedIrsDeployment {
    using DatedIrsDeployment for DatedIrsDeployment.Data;

    function load() external pure returns (bytes32 s) {
        DatedIrsDeployment.Data storage account = DatedIrsDeployment.load();
        assembly {
            s := account.slot
        }
    }

    function set(DatedIrsDeployment.Data memory config) external {
      DatedIrsDeployment.set(config);
    }

    function deploy(address ownerAddress) external returns (address datedIrsProxy) {
      datedIrsProxy = DatedIrsDeployment.deploy(ownerAddress);
    }

    function getDatedIrsRouter() external view returns (address) {
      return DatedIrsDeployment.load().datedIrsRouter;
    }
}

contract MockDatedIrsRouter is OwnerUpgradeModule {}

contract DatedIrsDeploymentTest is Test {
    ExposedDatedIrsDeployment internal datedIrsDeployment;

    bytes32 internal constant datedIrsDeploymentSlot = keccak256(abi.encode("xyz.voltz.CommunityDatedIrsDeployment"));

    function setUp() public {
        datedIrsDeployment = new ExposedDatedIrsDeployment();
    }

    function test_load() public {
      bytes32 slot = datedIrsDeployment.load();
      assertEq(slot, datedIrsDeploymentSlot);
    }

    function test_set() public {
      datedIrsDeployment.set(DatedIrsDeployment.Data({
        datedIrsRouter: address(1)
      }));

      assertEq(datedIrsDeployment.getDatedIrsRouter(), address(1));
    }

    function test_RevertWhen_NoDatedIrsRouter() public {
      vm.expectRevert(abi.encodeWithSelector(DatedIrsDeployment.MissingDatedIrsRouter.selector));
      datedIrsDeployment.set(DatedIrsDeployment.Data({
        datedIrsRouter: address(0)
      }));
    }

    function test_deploy() public {
      address datedIrsRouter = address(new MockDatedIrsRouter());
      datedIrsDeployment.set(DatedIrsDeployment.Data({
        datedIrsRouter: datedIrsRouter
      }));

      address ownerAddress = address(1234);
      address datedIrsProxy = datedIrsDeployment.deploy(ownerAddress);
      assert(datedIrsProxy != address(0));

      // accept ownership
      vm.prank(ownerAddress);
      Ownable(datedIrsProxy).acceptOwnership();

      assertEq(Ownable(datedIrsProxy).owner(), ownerAddress);
    }
}

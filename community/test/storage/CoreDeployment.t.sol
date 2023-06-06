pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "../../src/storage/CoreDeployment.sol";

import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";

import "@voltz-protocol/core/src/modules/AssociatedSystemsModule.sol";
import "@voltz-protocol/core/src/modules/AccountTokenModule.sol";

contract ExposedCoreDeployment {
    using CoreDeployment for CoreDeployment.Data;

    function load() external pure returns (bytes32 s) {
        CoreDeployment.Data storage account = CoreDeployment.load();
        assembly {
            s := account.slot
        }
    }

    function set(CoreDeployment.Data memory config) external {
      CoreDeployment.set(config);
    }

    function deploy(address ownerAddress) external returns (address coreProxy, address accountNftProxy) {
      (coreProxy, accountNftProxy) = CoreDeployment.deploy(ownerAddress);
    }

    function getCoreRouter() external view returns (address) {
      return CoreDeployment.load().coreRouter;
    }

    function getAccountNftRouter() external view returns (address) {
      return CoreDeployment.load().accountNftRouter;
    }

    function getAccountNftId() external view returns (bytes32) {
      return CoreDeployment.load().accountNftId;
    }

    function getAccountNftName() external view returns (string memory) {
      return CoreDeployment.load().accountNftName;
    }

    function getAccountNftSymbol() external view returns (string memory) {
      return CoreDeployment.load().accountNftSymbol;
    }

    function getAccountNftUri() external view returns (string memory) {
      return CoreDeployment.load().accountNftUri;
    }
}

contract MockCoreRouter is AssociatedSystemsModule, OwnerUpgradeModule {}
contract MockAccountNftRouter is AccountTokenModule, OwnerUpgradeModule {}

contract CoreDeploymentTest is Test {
    ExposedCoreDeployment internal coreDeployment;

    bytes32 internal constant coreDeploymentSlot = keccak256(abi.encode("xyz.voltz.CommunityCoreDeployment"));

    function setUp() public {
        coreDeployment = new ExposedCoreDeployment();
    }

    function test_load() public {
      bytes32 slot = coreDeployment.load();
      assertEq(slot, coreDeploymentSlot);
    }

    function test_set() public {
      coreDeployment.set(CoreDeployment.Data({
        coreRouter: address(1),
        accountNftRouter: address(2),
        accountNftId: bytes32("nftId"),
        accountNftName: "name",
        accountNftSymbol: "symbol",
        accountNftUri: "uri"
      }));

      assertEq(coreDeployment.getCoreRouter(), address(1));
      assertEq(coreDeployment.getAccountNftRouter(), address(2));
      assertEq(coreDeployment.getAccountNftId(), bytes32("nftId"));
      assertEq(coreDeployment.getAccountNftName(), "name");
      assertEq(coreDeployment.getAccountNftSymbol(), "symbol");
      assertEq(coreDeployment.getAccountNftUri(), "uri");
    }

    function test_RevertWhen_NoCoreRouter() public {
      vm.expectRevert(abi.encodeWithSelector(CoreDeployment.MissingCoreRouter.selector));
      coreDeployment.set(CoreDeployment.Data({
        coreRouter: address(0),
        accountNftRouter: address(2),
        accountNftId: bytes32("nftId"),
        accountNftName: "name",
        accountNftSymbol: "symbol",
        accountNftUri: "uri"
      }));

      vm.expectRevert(abi.encodeWithSelector(CoreDeployment.MissingCoreRouter.selector));
      coreDeployment.set(CoreDeployment.Data({
        coreRouter: address(0),
        accountNftRouter: address(0),
        accountNftId: bytes32("nftId"),
        accountNftName: "name",
        accountNftSymbol: "symbol",
        accountNftUri: "uri"
      }));
    }

    function test_RevertWhen_NoAccountNftRouter() public {
      vm.expectRevert(abi.encodeWithSelector(CoreDeployment.MissingAccountNftRouter.selector));
      coreDeployment.set(CoreDeployment.Data({
        coreRouter: address(1),
        accountNftRouter: address(0),
        accountNftId: bytes32("nftId"),
        accountNftName: "name",
        accountNftSymbol: "symbol",
        accountNftUri: "uri"
      }));
    }

    function test_deploy() public {
      address coreRouter = address(new MockCoreRouter());
      address accountNftRouter = address(new MockAccountNftRouter());
      coreDeployment.set(CoreDeployment.Data({
        coreRouter: coreRouter,
        accountNftRouter: accountNftRouter,
        accountNftId: bytes32("nftId"),
        accountNftName: "name",
        accountNftSymbol: "symbol",
        accountNftUri: "uri"
      }));

      address ownerAddress = address(1234);
      (address coreProxy, address accountNftProxy) = coreDeployment.deploy(ownerAddress);
      assert(coreProxy != address(0));
      assert(accountNftProxy != address(0));

      // accept ownership
      vm.prank(ownerAddress);
      Ownable(coreProxy).acceptOwnership();

      assertEq(Ownable(coreProxy).owner(), ownerAddress);
      assertEq(Ownable(accountNftProxy).owner(), coreProxy);
    }
}

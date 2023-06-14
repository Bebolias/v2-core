pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "../src/CommunityDeployer.sol";

import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import "@voltz-protocol/core/src/modules/AccountTokenModule.sol";

contract MockCoreRouter is AssociatedSystemsModule, OwnerUpgradeModule {}
contract MockAccountNftRouter is AccountTokenModule, OwnerUpgradeModule {}
contract MockDatedIrsRouter is OwnerUpgradeModule {}
contract MockPeripheryRouter is OwnerUpgradeModule {}
contract MockVammRouter is OwnerUpgradeModule {}

contract MockCommunityDeployer is CommunityDeployer {
  constructor(
    uint256 _quorumVotes,
    address _ownerAddress,
    bytes32 _merkleRoot,
    uint256 _blockTimestampVotingEnd,
    CoreDeployment.Data memory _coreDeploymentConfig,
    DatedIrsDeployment.Data memory _datedIrsDeploymentConfig,
    PeripheryDeployment.Data memory _peripheryDeploymentConfig,
    VammDeployment.Data memory _vammDeploymentConfig
  ) CommunityDeployer(
    _quorumVotes,
    _ownerAddress,
    _merkleRoot,
    _blockTimestampVotingEnd,
    _coreDeploymentConfig,
    _datedIrsDeploymentConfig,
    _peripheryDeploymentConfig,
    _vammDeploymentConfig
  ) {}

  function mockVoteYes() public {
    yesVoteCount += 1;
  }
}

contract CommunityDeployerTest is Test {
  address internal coreRouter;
  address internal accountNftRouter;
  address internal datedIrsRouter;
  address internal peripheryRouter;
  address internal vammRouter;

  function setUp() public {
    coreRouter = address(new MockCoreRouter());
    accountNftRouter = address(new MockAccountNftRouter());
    datedIrsRouter = address(new MockDatedIrsRouter());
    peripheryRouter = address(new MockPeripheryRouter());
    vammRouter = address(new MockVammRouter());
  }

  function test_deploy() public {
    vm.warp(1);

    address ownerAddress = address(1234);
    MockCommunityDeployer communityDeployer = new MockCommunityDeployer(
      1,
      ownerAddress,
      bytes32("merkleRoot"),
      10,
      CoreDeployment.Data({
        coreRouter: coreRouter,
        accountNftRouter: accountNftRouter,
        accountNftId: bytes32("nftId"),
        accountNftName: "name",
        accountNftSymbol: "symbol",
        accountNftUri: "uri"
      }),
      DatedIrsDeployment.Data({
        datedIrsRouter: datedIrsRouter
      }),
      PeripheryDeployment.Data({
        peripheryRouter: peripheryRouter
      }),
      VammDeployment.Data({
        vammRouter: vammRouter
      })
    );

    communityDeployer.mockVoteYes();
    vm.warp(11);
    communityDeployer.queue();

    vm.warp(11 + communityDeployer.TIMELOCK_PERIOD_IN_SECONDS() + 1);
    communityDeployer.deploy();

    address coreProxy = communityDeployer.coreProxy();
    assert(coreProxy != address(0));
    // accept ownership
    vm.prank(ownerAddress);
    Ownable(coreProxy).acceptOwnership();
    assertEq(Ownable(coreProxy).owner(), ownerAddress);
    assertEq(Ownable(communityDeployer.accountNftProxy()).owner(), coreProxy);

    address datedIrsProxy = communityDeployer.datedIrsProxy();
    assert(datedIrsProxy != address(0));
    // accept ownership
    vm.prank(ownerAddress);
    Ownable(datedIrsProxy).acceptOwnership();
    assertEq(Ownable(datedIrsProxy).owner(), ownerAddress);

    address peripheryProxy = communityDeployer.peripheryProxy();
    assert(peripheryProxy != address(0));
    // accept ownership
    vm.prank(ownerAddress);
    Ownable(peripheryProxy).acceptOwnership();
    assertEq(Ownable(peripheryProxy).owner(), ownerAddress);

    address vammProxy = communityDeployer.vammProxy();
    assert(vammProxy != address(0));
    // accept ownership
    vm.prank(ownerAddress);
    Ownable(vammProxy).acceptOwnership();
    assertEq(Ownable(vammProxy).owner(), ownerAddress);

    vm.startPrank(ownerAddress);
    address coreRouter2 = address(new MockCoreRouter());
    OwnerUpgradeModule(coreProxy).upgradeTo(coreRouter2);
    assertEq(OwnerUpgradeModule(coreProxy).getImplementation(), coreRouter2);
  }
}
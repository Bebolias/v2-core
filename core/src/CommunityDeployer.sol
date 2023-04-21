//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./CoreProxy.sol";
import "./modules/AssociatedSystemsModule.sol";
import "./modules/InitialModuleBundle.sol";
import "oz/utils/cryptography/MerkleProof.sol";

contract CommunityDeployer {
    /// @notice Timelock Period In Seconds, once the deployment is queued, 2 days need to pass in order to make deployment of the Voltz Factory possible
    uint256 public constant TIMELOCK_PERIOD_IN_SECONDS = 2 days;

    /// @notice Multisig owner address
    address public ownerAddress;

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint256 public quorumVotes;

    /// @notice Voltz Protocol V2 Core Router
    address public coreRouter;

    /// @notice Voltz Protocol V2 Account NFT Router
    address public accountNftRouter;

    /// @notice Id of Voltz Protocol V2 Account NFT as stored in the core proxy's associated system
    bytes32 public accountNftId;

    /// @notice Name of Voltz Protocol V2 Account NFT
    string public accountNftName; 

    /// @notice Symbol of Voltz Protocol V2 Account NFT
    string public accountNftSymbol; 

    /// @notice Uri of Voltz Protocol V2 Account NFT 
    string public accountNftUri;

    /// @notice Total number of votes in favour of deploying Voltz Protocol V2 Core
    uint256 public yesVoteCount;

    /// @notice Total number of votes against the deployment of Voltz Protocol V2 Core
    uint256 public noVoteCount;

    /// @notice voting end block timestamp (once this contract is deployed, voting is considered to be officially started)
    uint256 public blockTimestampVotingEnd;

    /// @notice timelock end block timestamp (once the proposal is queued, the timelock period pre-deployment is considered to be officially started)
    uint256 public blockTimestampTimelockEnd;

    /// @notice isQueued needs to be true in order for the timelock period to start in advance of the deployment
    bool public isQueued;

    /// @notice isDeployed makes sure contract is deploying at most one Core Proxy
    bool public isDeployed;

    /// @notice Voltz V2 Core Proxy to be deployed in a scenario where a successful vote is followed by the queue and deployment
    CoreProxy public coreProxy;

    // Merkle Tree
    bytes32 public merkleRoot;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private votedBitMap;

    // This event is triggered whenever a call to cast a vote succeeds
    event Voted(
        uint256 index,
        address account,
        uint256 numberOfVotes,
        bool yesVote
    );

    constructor(
        address _coreRouter,
        address _accountNftRouter,
        bytes32 _accountNftId, 
        string memory _accountNftName, 
        string memory _accountNftSymbol, 
        string memory _accountNftUri,
        uint256 _quorumVotes,
        address _ownerAddress,
        bytes32 _merkleRoot,
        uint256 _blockTimestampVotingEnd
    ) {
        coreRouter = _coreRouter;
        accountNftRouter = _accountNftRouter;
        accountNftId = _accountNftId;
        accountNftName = _accountNftName;
        accountNftSymbol = _accountNftSymbol;
        accountNftUri = _accountNftUri;
        quorumVotes = _quorumVotes;
        ownerAddress = _ownerAddress;
        merkleRoot = _merkleRoot;
        blockTimestampVotingEnd = _blockTimestampVotingEnd;
    }

    function hasVoted(uint256 index) public view returns (bool) {
        uint256 votedWordIndex = index / 256;
        uint256 votedBitIndex = index % 256;
        uint256 votedWord = votedBitMap[votedWordIndex];
        uint256 mask = (1 << votedBitIndex);
        return votedWord & mask == mask;
    }

    function _setVoted(uint256 index) private {
        uint256 votedWordIndex = index / 256;
        uint256 votedBitIndex = index % 256;
        votedBitMap[votedWordIndex] =
            votedBitMap[votedWordIndex] |
            (1 << votedBitIndex);
    }

    /// @notice Deploy the Voltz Factory by passing the masterVAMM and the masterMarginEngine into the Factory constructor
    function deploy() external {
        require(isQueued, "not queued");
        require(
            block.timestamp > blockTimestampTimelockEnd,
            "timelock is ongoing"
        );
        require(isDeployed == false, "already deployed");
       
        coreProxy = new CoreProxy(coreRouter, address(this));
        AssociatedSystemsModule(address(coreProxy)).initOrUpgradeNft(
            accountNftId,
            accountNftName,
            accountNftSymbol,
            accountNftUri,
            accountNftRouter
        );
        InitialModuleBundle(address(coreProxy)).nominateNewOwner(ownerAddress);

        isDeployed = true;
    }

    /// @notice Queue the deployment of the Voltz Factory
    function queue() external {
        require(block.timestamp > blockTimestampVotingEnd, "voting is ongoing");
        require(yesVoteCount >= quorumVotes, "quorum not reached");
        require(yesVoteCount > noVoteCount, "no >= yes");
        require(isQueued == false, "already queued");
        isQueued = true;
        blockTimestampTimelockEnd =
            block.timestamp +
            TIMELOCK_PERIOD_IN_SECONDS;
    }

    /// @notice Vote for the proposal to deploy the Voltz Factory contract
    /// @param _index index of the voter
    /// @param _numberOfVotes number of voltz genesis nfts held by the msg.sender before the snapshot was taken
    /// @param _yesVote if this boolean is true then the msg.sender is casting a yes vote, if the boolean is false the msg.sender is casting a no vote
    /// @param _merkleProof merkle proof that needs to be verified against the merkle root to check the msg.sender against the snapshot
    function castVote(
        uint256 _index,
        uint256 _numberOfVotes,
        bool _yesVote,
        bytes32[] calldata _merkleProof
    ) external {
        require(
            block.timestamp <= blockTimestampVotingEnd,
            "voting period over"
        );

        // check if msg.sender has already voted
        require(!hasVoted(_index), "duplicate vote");

        // verify the merkle proof
        bytes32 _node = keccak256(
            abi.encodePacked(_index, msg.sender, _numberOfVotes)
        );
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, _node),
            "invalid merkle proof"
        );

        // mark hasVoted
        _setVoted(_index);

        // cast the vote
        if (_yesVote) {
            yesVoteCount += _numberOfVotes;
        } else {
            noVoteCount += _numberOfVotes;
        }

        // emit an event
        emit Voted(_index, msg.sender, _numberOfVotes, _yesVote);
    }
}

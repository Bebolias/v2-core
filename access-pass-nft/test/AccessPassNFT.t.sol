pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../src/AccessPassNFT.sol";
import "oz/utils/cryptography/MerkleProof.sol";



contract AccessPassNFTTest is Test {

    AccessPassNFT internal accessPassNFT;
    string internal constant ACCESS_PASS_NFT_NAME = "AccessPassNFT";
    string internal constant ACCESS_PASS_NFT_SYMBOL = "APNFT";
    bytes32 internal constant MERKLE_ROOT = "0x1234";
    string internal constant BASE_METADATA_URI = "ipfs://QmWKUhiBh7efyvRDDfeyDXKh9KrzchEGCJAVMcTqZezSPg/";
    uint256 internal constant NUMBER_OF_ACCESS_PASSES = 5;

    function setUp() public {
        accessPassNFT = new AccessPassNFT(ACCESS_PASS_NFT_NAME, ACCESS_PASS_NFT_SYMBOL);
    }

    function testSuccessfulAddNewRoot() public {

        AccessPassNFT.RootInfo memory rootInfo = AccessPassNFT.RootInfo({
            merkleRoot: MERKLE_ROOT,
            baseMetadataURI: BASE_METADATA_URI
        });

        accessPassNFT.addNewRoot(rootInfo);
        string memory baseMetadataURI = accessPassNFT.whitelistedMerkleRootToURI(MERKLE_ROOT);
        assertEq(baseMetadataURI, BASE_METADATA_URI);

    }

    function testSuccessfulRedeem() public {

        AccessPassNFT.RootInfo memory rootInfo = AccessPassNFT.RootInfo({
            merkleRoot: MERKLE_ROOT,
            baseMetadataURI: BASE_METADATA_URI
        });

        accessPassNFT.addNewRoot(rootInfo);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(uint256(1));

        accessPassNFT.redeem(address(this), NUMBER_OF_ACCESS_PASSES, proof, MERKLE_ROOT);

    }

}



pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../src/AccessPassNFT.sol";
import "oz/utils/cryptography/MerkleProof.sol";
import "oz/token/ERC721/IERC721Receiver.sol";

contract AccessPassNFTTest is Test, IERC721Receiver {

    AccessPassNFT internal accessPassNFT;
    string internal constant ACCESS_PASS_NFT_NAME = "AccessPassNFT";
    string internal constant ACCESS_PASS_NFT_SYMBOL = "APNFT";
    bytes32 internal constant MERKLE_ROOT = 0xf1197aaf943f940ff63c7c8c929a35decf1473ff6cdaac3b88b9c8db3aa3e2a9;
    string internal constant BASE_METADATA_URI = "ipfs://QmWKUhiBh7efyvRDDfeyDXKh9KrzchEGCJAVMcTqZezSPg/";
    uint256 internal constant NUMBER_OF_ACCESS_PASSES = 3;

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
        external
        returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

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
        proof[0] = 0x2a5bb61d4b6540294819af4b6a2b302e0fcb2b698020f535cd8182b0a910da9f;

        accessPassNFT.redeem(address(this), NUMBER_OF_ACCESS_PASSES, proof, MERKLE_ROOT);

    }

    function testSuccessfulRedeemEOAAccount() public {

        AccessPassNFT.RootInfo memory rootInfo = AccessPassNFT.RootInfo({
            merkleRoot: MERKLE_ROOT,
            baseMetadataURI: BASE_METADATA_URI
        });

        accessPassNFT.addNewRoot(rootInfo);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0xa57c39cbcd238da0214df3df9ed8814d268c19f6440c6cfdd5fe9ae1251055c3;

        accessPassNFT.redeem(address(1), 1, proof, MERKLE_ROOT);

    }

    function testTokenURI() public {}

    function testSuccessfulNFTTransfer() public {}

    function testDeleteRoot() public {}

    function testFailRedeemWithUnrecognisedMerkleRoot() public {}

    function testFailRedeemWithInvalidMerkleProof() public {}

    function testFailDoubleRedeem() public {}

    function testFailDeleteRootNotOwner() public {}

    function testFailAddNewRootNotOwner() public {}

}



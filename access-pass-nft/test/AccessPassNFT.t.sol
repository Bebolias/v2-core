pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../src/AccessPassNFT.sol";

contract AccessPassNFTTest is Test {

    AccessPassNFT internal accessPassNFT;
    string internal constant ACCESS_PASS_NFT_NAME = "AccessPassNFT";
    string internal constant ACCESS_PASS_NFT_SYMBOL = "APNFT";
    bytes32 internal constant MERKLE_ROOT = "0x1234";
    string internal constant BASE_METADATA_URI = "ipfs://QmWKUhiBh7efyvRDDfeyDXKh9KrzchEGCJAVMcTqZezSPg/";

    function setUp() public {
        accessPassNFT = new AccessPassNFT(ACCESS_PASS_NFT_NAME, ACCESS_PASS_NFT_SYMBOL);
    }

    function testSuccessfulAddNewRoot() public {

        AccessPassNFT.RootInfo memory rootInfo = AccessPassNFT.RootInfo({
            merkleRoot: MERKLE_ROOT,
            baseMetadataURI: BASE_METADATA_URI,
            startTimestamp: 0,
            endTimestamp: 1
        });

        accessPassNFT.addNewRoot(rootInfo);
        string memory baseMetadataURI = accessPassNFT.rootData(MERKLE_ROOT);
        assertEq(baseMetadataURI, BASE_METADATA_URI);

    }

}

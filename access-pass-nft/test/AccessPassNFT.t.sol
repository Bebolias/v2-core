pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../src/AccessPassNFT.sol";

contract AccessPassNFTTest is Test {

    AccessPassNFT internal accessPassNFT;
    constant string ACCESS_PASS_NFT_NAME = "AccessPassNFT";
    constant string ACCESS_PASS_NFT_SYMBOL = "APNFT";
    constant bytes32 MERKLE_ROOT = bytes32(0x1234);
    constant string BASE_METADATA_URI = "ipfs://QmWKUhiBh7efyvRDDfeyDXKh9KrzchEGCJAVMcTqZezSPg/";

    function setUp() public {
        accessPassNFT = new AccessPassNFT(ACCESS_PASS_NFT_NAME, ACCESS_PASS_NFT_SYMBOL);
    }

    function testSuccessfulAddNewRoot() public {

        RootInfoStruct memory rootInfo = {
            merkleRoot: MERKLE_ROOT,
            baseMetadataURI: BASE_METADATA_URI,
            startTimestamp: 0,
            endTimestamp: 1
        };

        accessPassNFT.addNewRoot(rootInfo);
        baseMetadataURI = accessPassNFT.rootData(MERKLE_ROOT);
        assert(baseMetadataURI == BASE_METADATA_URI);

    }

    }

}
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../src/mocks/AccessPassNFTMock.sol";

contract AccessPassNFTMockTest is Test {

    AccessPassNFTMock internal accessPassNFTMock;
    string internal constant ACCESS_PASS_NFT_NAME = "AccessPassNFT";
    string internal constant ACCESS_PASS_NFT_SYMBOL = "APNFT";

    function setUp() public {
        accessPassNFTMock = new AccessPassNFTMock(ACCESS_PASS_NFT_NAME, ACCESS_PASS_NFT_SYMBOL);
    }

    function testFuzz_BalanceAlwaysOne(address owner) public {
        uint256 balance1 = accessPassNFTMock.balanceOf(owner);
        assertEq(balance1, 1);
    }
}



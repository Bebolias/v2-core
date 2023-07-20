// !!! ONLY FOR TESTNET !!!!!
pragma solidity >=0.8.19;

import "../AccessPassNFT.sol";

contract AccessPassNFTMock is AccessPassNFT {

    constructor(
        string memory name,
        string memory symbol
    ) AccessPassNFT(name, symbol) {}

    /**
     * @inheritdoc IERC721
     */
    function balanceOf(address holder) public view virtual override(ERC721, IERC721) returns (uint256) {
        return 1;
    }
}


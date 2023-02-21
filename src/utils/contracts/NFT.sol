// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./initializable/InitializableMixin.sol";
import "../errors/AddressError.sol";
import "../helpers/AddressUtil.sol";
import "../storage/OwnableStorage.sol";
import "../storage/Initialized.sol";
import "./token/ERC721Enumerable.sol";
import "../interfaces/INFT.sol";

/**
 * @title Module wrapping an ERC721 token implementation.
 * See INFT.
 */
contract NFT is INFT, ERC721Enumerable, InitializableMixin {
    bytes32 internal constant _INITIALIZED_NAME = "NFT";

    /**
     * @inheritdoc INFT
     */
    function isInitialized() external view returns (bool) {
        return _isInitialized();
    }

    /**
     * @inheritdoc INFT
     */
    function initialize(string memory tokenName, string memory tokenSymbol, string memory uri) public {
        OwnableStorage.onlyOwner();

        _initialize(tokenName, tokenSymbol, uri);
        Initialized.load(_INITIALIZED_NAME).initialized = true;
    }

    /**
     * @inheritdoc INFT
     */
    function burn(uint256 tokenId) external override {
        OwnableStorage.onlyOwner();
        _burn(tokenId);
    }

    /**
     * @inheritdoc INFT
     */
    function mint(address to, uint256 tokenId) external override {
        OwnableStorage.onlyOwner();
        _mint(to, tokenId);
    }

    /**
     * @inheritdoc INFT
     */
    function safeMint(address to, uint256 tokenId, bytes memory data) external override {
        OwnableStorage.onlyOwner();
        _mint(to, tokenId);

        if (!_checkOnERC721Received(address(0), to, tokenId, data)) {
            revert InvalidTransferRecipient(to);
        }
    }

    /**
     * @inheritdoc INFT
     */
    function setAllowance(uint256 tokenId, address spender) external override {
        OwnableStorage.onlyOwner();
        ERC721Storage.load().tokenApprovals[tokenId] = spender;
    }

    function _isInitialized() internal view override returns (bool) {
        return Initialized.load(_INITIALIZED_NAME).initialized;
    }
}

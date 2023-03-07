// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IAccountTokenModule.sol";
import "../interfaces/IAccountModule.sol";
import "../utils/contracts/helpers/SafeCast.sol";
import "../utils/modules/modules/NftModule.sol";

/**
 * @title Account Token
 * @dev See IAccountTokenModule
 */
contract AccountTokenModule is IAccountTokenModule, NFT {
    using SafeCastU256 for uint256;

    /**
     * @dev Updates account RBAC storage to track the current owner of the token.
     */
    function _postTransfer(
        address, // from (unused)
        address to,
        uint256 tokenId
    ) internal virtual override {
        IAccountModule(OwnableStorage.getOwner()).notifyAccountTransfer(to, tokenId.to128());
    }
}

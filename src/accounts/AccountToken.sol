// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IAccountToken.sol";
import "../interfaces/IAccountManager.sol";
import "../utils/helpers/SafeCast.sol";
import "../utils/contracts/NFT.sol";

/**
 * @title Account Token
 * @dev See IAccountToken
 */
contract AccountToken is IAccountToken, NFT {
    using SafeCastU256 for uint256;

    /**
     * @dev Updates account RBAC storage to track the current owner of the token.
     */
    function _postTransfer(
        address, // from (unused)
        address to,
        uint256 tokenId
    )
        internal
        virtual
        override
    {
        IAccountManager(OwnableStorage.getOwner()).notifyAccountTransfer(to, tokenId.to128());
    }
}

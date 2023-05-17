pragma solidity >=0.8.19;

import "../interfaces/IAccountTokenModule.sol";
import "../interfaces/IAccountModule.sol";
import "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";
import "@voltz-protocol/util-modules/src/modules/NftModule.sol";

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

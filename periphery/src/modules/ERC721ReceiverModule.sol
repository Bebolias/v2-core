pragma solidity >=0.8.19;

import {Config} from "../storage/Config.sol";
import {IERC721} from "@voltz-protocol/util-contracts/src/interfaces/IERC721.sol";
import {IERC721Receiver} from "@voltz-protocol/util-contracts/src/interfaces/IERC721Receiver.sol";

// solhint-disable-next-line no-empty-blocks
contract ERC721ReceiverModule is IERC721Receiver {
  /**
    * @inheritdoc IERC721Receiver
    */
  function onERC721Received(address operator, address, uint256, bytes memory)
    external view override
    returns (bytes4) 
  {
    if (operator != Config.load().VOLTZ_V2_CORE_PROXY) {
      return 0;
    }

    return IERC721Receiver.onERC721Received.selector;
  }
}

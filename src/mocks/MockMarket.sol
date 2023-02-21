// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IMarket.sol";
import "../interfaces/IMarketManager.sol";

contract MockMarket is IMarket {
    address private _proxy;
    uint128 private _marketId;
    uint256 private _price;

    function initialize(address proxy, uint128 marketId, uint256 initialPrice) external {
        _proxy = proxy;
        _marketId = marketId;
        _price = initialPrice;
    }

    function name(uint128) external pure override returns (string memory) {
        return "MockMarket";
    }

    function setPrice(uint256 newPrice) external {
        _price = newPrice;
    }

    function price() external view returns (uint256) {
        return _price;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IMarket).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../../src/core/interfaces/external/IProduct.sol";

contract MockProduct is IProduct {
    string internal _name;

    constructor(string memory name) {
        _name = name;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    // getAccountUnrealizedPnL mock support
    struct MockAccountUnrealizedPnL {
        mapping(uint256 => int256) returnValues;
        uint256 start;
        uint256 end;
    }

    mapping(uint128 => MockAccountUnrealizedPnL) internal mockAccountUnrealizedPnL;

    function mockGetAccountUnrealizedPnL(uint128 accountId, int256 returnValue) public {
        MockAccountUnrealizedPnL storage tmp = mockAccountUnrealizedPnL[accountId];
        tmp.returnValues[tmp.end] = returnValue;
        tmp.end += 1;
    }

    function skipGetAccountUnrealizedPnLMock(uint128 accountId) public {
        MockAccountUnrealizedPnL storage tmp = mockAccountUnrealizedPnL[accountId];

        if (tmp.end - tmp.start >= 2) {
            tmp.start += 1;
        }
    }

    function getAccountUnrealizedPnL(uint128 accountId) public view override returns (int256 unrealizedPnL) {
        MockAccountUnrealizedPnL storage tmp = mockAccountUnrealizedPnL[accountId];

        if (tmp.start >= tmp.end) {
            revert("Unmocked call");
        }

        return tmp.returnValues[tmp.start];
    }

    // getAccountAnnualizedExposures mock support
    struct MockAccountAnnualizedExposure {
        mapping(uint256 => Account.Exposure[]) returnValues;
        uint256 start;
        uint256 end;
    }

    mapping(uint128 => MockAccountAnnualizedExposure) internal mockAccountAnnualizedExposures;

    function mockGetAccountAnnualizedExposures(uint128 accountId, Account.Exposure[] memory returnValue) public {
        MockAccountAnnualizedExposure storage tmp = mockAccountAnnualizedExposures[accountId];
        for (uint256 i = 0; i < returnValue.length; i++) {
            tmp.returnValues[tmp.end].push(returnValue[i]);
        }

        tmp.end += 1;
    }

    function skipGetAccountAnnualizedExposures(uint128 accountId) public {
        MockAccountAnnualizedExposure storage tmp = mockAccountAnnualizedExposures[accountId];

        if (tmp.end - tmp.start >= 2) {
            tmp.start += 1;
        }
    }

    function getAccountAnnualizedExposures(uint128 accountId) public view returns (Account.Exposure[] memory exposures) {
        MockAccountAnnualizedExposure storage tmp = mockAccountAnnualizedExposures[accountId];

        if (tmp.start >= tmp.end) {
            revert("Unmocked call");
        }

        return tmp.returnValues[tmp.start];
    }

    // supportsInterface mock support
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }

    // closeAccount mock support
    function closeAccount(uint128 accountId) public override {
        skipGetAccountUnrealizedPnLMock(accountId);
        skipGetAccountAnnualizedExposures(accountId);
    }
}

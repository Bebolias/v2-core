/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "../../src/interfaces/external/IProduct.sol";

contract MockProduct is IProduct {
    string internal _name;

    constructor(string memory productName) {
        _name = productName;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    mapping(uint128 => mapping(uint256 => uint256)) internal mockBaseToAnnualizedFactor;

    function mockBaseToAnnualizedExposure(uint128 marketId, uint32 maturityTimestamp, uint256 baseToAnnualizedFactor)
        public
    {
        mockBaseToAnnualizedFactor[marketId][maturityTimestamp] = baseToAnnualizedFactor;
    }

    function baseToAnnualizedExposure(int256[] memory baseAmounts, uint128 marketId, uint32 maturityTimestamp)
        external
        view
        returns (int256[] memory exposures)
    {
        exposures = new int256[](baseAmounts.length);
        for (uint256 i = 0; i < baseAmounts.length; i += 1) {
            exposures[i] = baseAmounts[i] * int256(mockBaseToAnnualizedFactor[marketId][maturityTimestamp]) / 1e18;
        }
    }

    // getAccountAnnualizedExposures mock support
    struct MockAccountMakerAndTakerExposures {
        mapping(uint256 => Account.Exposure[]) takerExposuresReturnValues;
        mapping(uint256 => Account.Exposure[]) makerLowerExposuresReturnValues;
        mapping(uint256 => Account.Exposure[]) makerUpperExposuresReturnValues;
        uint256 start;
        uint256 end;
    }

    mapping(uint128 => mapping(address => MockAccountMakerAndTakerExposures)) internal mockAccountTakerAndMakerExposures;

    function mockGetAccountTakerAndMakerExposures(
        uint128 accountId,
        address collateralType,
        Account.Exposure[] memory takerExposuresReturnValues,
        Account.Exposure[] memory makerLowerExposuresReturnValues,
        Account.Exposure[] memory makerUpperExposuresReturnValues
    ) public {
        MockAccountMakerAndTakerExposures storage tmp = mockAccountTakerAndMakerExposures[accountId][collateralType];
        for (uint256 i = 0; i < takerExposuresReturnValues.length; i++) {
            tmp.takerExposuresReturnValues[tmp.end].push(takerExposuresReturnValues[i]);
        }

        // todo: assert makerLowerExposuresReturnValues.length == makerUpperExposuresReturnValues.length
        for (uint256 i = 0; i < makerLowerExposuresReturnValues.length; i++) {
            tmp.makerLowerExposuresReturnValues[tmp.end].push(makerLowerExposuresReturnValues[i]);
            tmp.makerUpperExposuresReturnValues[tmp.end].push(makerUpperExposuresReturnValues[i]);
        }

        tmp.end += 1;
    }

    function skipGetAccountTakerAndMakerExposures(uint128 accountId, address collateralType) public {
        MockAccountMakerAndTakerExposures storage tmp = mockAccountTakerAndMakerExposures[accountId][collateralType];

        if (tmp.end - tmp.start >= 2) {
            tmp.start += 1;
        }
    }

    function getAccountTakerAndMakerExposures(uint128 accountId, address collateralType)
        public
        view
        returns (Account.Exposure[] memory takerExposures, Account.Exposure[] memory makerLowerExposures, Account.Exposure[] memory makerUpperExposures)
    {
        MockAccountMakerAndTakerExposures storage tmp = mockAccountTakerAndMakerExposures[accountId][collateralType];

        if (tmp.start >= tmp.end) {
            revert("Unmocked call");
        }

        return (tmp.takerExposuresReturnValues[tmp.start], tmp.makerLowerExposuresReturnValues[tmp.start], tmp.makerUpperExposuresReturnValues[tmp.start]);
    }

    // supportsInterface mock support
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }

    // closeAccount mock support
    function closeAccount(uint128 accountId, address collateralType) public override {
        skipGetAccountTakerAndMakerExposures(accountId, collateralType);
    }
}

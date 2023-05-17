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

    // getAccountUnrealizedPnL mock support
    struct MockAccountUnrealizedPnL {
        mapping(uint256 => int256) returnValues;
        uint256 start;
        uint256 end;
    }

    mapping(uint128 => mapping(address => MockAccountUnrealizedPnL)) internal mockAccountUnrealizedPnL;

    function mockGetAccountUnrealizedPnL(uint128 accountId, address collateralType, int256 returnValue) public {
        MockAccountUnrealizedPnL storage tmp = mockAccountUnrealizedPnL[accountId][collateralType];
        tmp.returnValues[tmp.end] = returnValue;
        tmp.end += 1;
    }

    function skipGetAccountUnrealizedPnLMock(uint128 accountId, address collateralType) public {
        MockAccountUnrealizedPnL storage tmp = mockAccountUnrealizedPnL[accountId][collateralType];

        if (tmp.end - tmp.start >= 2) {
            tmp.start += 1;
        }
    }

    function getAccountUnrealizedPnL(uint128 accountId, address collateralType)
        public
        view
        override
        returns (int256 unrealizedPnL)
    {
        MockAccountUnrealizedPnL storage tmp = mockAccountUnrealizedPnL[accountId][collateralType];

        if (tmp.start >= tmp.end) {
            revert("Unmocked call");
        }

        return tmp.returnValues[tmp.start];
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
    struct MockAccountAnnualizedExposure {
        mapping(uint256 => Account.Exposure[]) returnValues;
        uint256 start;
        uint256 end;
    }

    mapping(uint128 => mapping(address => MockAccountAnnualizedExposure)) internal mockAccountAnnualizedExposures;

    function mockGetAccountAnnualizedExposures(
        uint128 accountId,
        address colalteralType,
        Account.Exposure[] memory returnValue
    ) public {
        MockAccountAnnualizedExposure storage tmp = mockAccountAnnualizedExposures[accountId][colalteralType];
        for (uint256 i = 0; i < returnValue.length; i++) {
            tmp.returnValues[tmp.end].push(returnValue[i]);
        }

        tmp.end += 1;
    }

    function skipGetAccountAnnualizedExposures(uint128 accountId, address collateralType) public {
        MockAccountAnnualizedExposure storage tmp = mockAccountAnnualizedExposures[accountId][collateralType];

        if (tmp.end - tmp.start >= 2) {
            tmp.start += 1;
        }
    }

    function getAccountAnnualizedExposures(uint128 accountId, address collateralType)
        public
        view
        returns (Account.Exposure[] memory exposures)
    {
        MockAccountAnnualizedExposure storage tmp = mockAccountAnnualizedExposures[accountId][collateralType];

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
    function closeAccount(uint128 accountId, address collateralType) public override {
        skipGetAccountUnrealizedPnLMock(accountId, collateralType);
        skipGetAccountAnnualizedExposures(accountId, collateralType);
    }
}

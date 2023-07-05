/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import "../mocks/MockRateOracle.sol";
import "../../src/oracles/AaveV3RateOracle.sol";
import "../../src/modules/RateOracleModule.sol";
import "../../src/storage/RateOracleReader.sol";
import "../../src/interfaces/IRateOracleModule.sol";
import "../../src/interfaces/IRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

contract RateOracleModuleExtended is RateOracleModule {
    using RateOracleReader for RateOracleReader.Data;

    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }

    // mock function, this is not visible in production
    function updateCache(uint128 id, uint32 maturityTimestamp) external {
        RateOracleReader.load(id).updateRateIndexAtMaturityCache(maturityTimestamp);
    }
}

contract ERC165 is IERC165 {
    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool) {
        return interfaceId == this.supportsInterface.selector;
    }
}

contract RateOracleModuleTest is Test {
    using { unwrap } for UD60x18;

    RateOracleModuleExtended RateOracleModule;

    using RateOracleReader for RateOracleReader.Data;

    event RateOracleConfigured(uint128 indexed marketId, address indexed oracleAddress, uint256 blockTimestamp,
        uint256 maturityIndexCachingWindowInSeconds);

    MockRateOracle mockRateOracle;
    uint32 public maturityTimestamp;
    uint128 public marketId;

    function setUp() public virtual {
        RateOracleModule = new RateOracleModuleExtended();
        RateOracleModule.setOwner(address(this));

        mockRateOracle = new MockRateOracle();

        maturityTimestamp = Time.blockTimestampTruncated() + 31536000;
        marketId = 100;

        RateOracleModule.setVariableOracle(marketId, address(mockRateOracle), 3600);
    }

    function test_InitSetVariableOracle() public {
        // expect RateOracleConfigured event
        vm.expectEmit(true, true, false, true);
        emit RateOracleConfigured(200, address(mockRateOracle), 3600, block.timestamp);

        RateOracleModule.setVariableOracle(200, address(mockRateOracle), 3600);
    }

    function test_ResetExistingOracle() public {
        address newRateOracle = address(new MockRateOracle());
        RateOracleModule.setVariableOracle(marketId, address(newRateOracle), 3600);
        // todo: check set variable oracle once we add getter function (AB)
    }

    function test_RevertWhen_SetOracleWrongInterface() public {
        ERC165 fakeOracle = new ERC165();

        vm.expectRevert(abi.encodeWithSelector(IRateOracleModule.InvalidVariableOracleAddress.selector, address(fakeOracle)));

        RateOracleModule.setVariableOracle(200, address(fakeOracle), 3600);
    }

    function test_InitGetRateIndexCurrent() public {
        UD60x18 rateIndexCurrent = RateOracleModule.getRateIndexCurrent(marketId);
        assertEq(rateIndexCurrent.unwrap(), 0);
    }

    function test_GetRateIndexCurrentBeforeMaturity() public {
        mockRateOracle.setLastUpdatedIndex(1.001e18 * 1e9);
        UD60x18 rateIndexCurrent = RateOracleModule.getRateIndexCurrent(marketId);
        assertEq(rateIndexCurrent.unwrap(), 1.001e18);
    }


    function test_NoCacheBeforeMaturity() public {
        UD60x18 rateIndexCurrent = RateOracleModule.getRateIndexCurrent(marketId);
    }

    function test_GetRateIndexMaturity() public {
        vm.warp(maturityTimestamp + 1);

        uint256 indexToSet = 1.001e18;

        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        RateOracleModule.updateRateIndexAtMaturityCache(marketId, maturityTimestamp);

        UD60x18 rateIndexMaturity = RateOracleModule.getRateIndexMaturity(marketId, maturityTimestamp);
        assertEq(rateIndexMaturity.unwrap(), indexToSet);
    }

    function test_RevertWhen_GetRateIndexMaturityBeforeMaturity() public {
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityNotReached.selector));

        RateOracleModule.getRateIndexMaturity(marketId, maturityTimestamp);
    }
}

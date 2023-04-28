pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import "./mocks/MockRateOracle.sol";
import "../src/oracles/AaveRateOracle.sol";
import "../src/modules/RateOracleManager.sol";
import "../src/storage/RateOracleReader.sol";
import "../src/interfaces/IRateOracleModule.sol";
import "../src/interfaces/IRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18, unwrap } from "@prb/math/UD60x18.sol";

contract RateOracleManagerExtended is RateOracleManager {
    using RateOracleReader for RateOracleReader.Data;

    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }

    // mock function, this is not visible in production
    function updateCache(uint128 id, uint32 maturityTimestamp) external {
        RateOracleReader.load(id).updateCache(maturityTimestamp);
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

contract RateOracleManagerTest is Test {
    using { unwrap } for UD60x18;

    RateOracleManagerExtended rateOracleManager;

    using RateOracleReader for RateOracleReader.Data;

    event RateOracleRegistered(uint128 indexed marketId, address indexed oracleAddress);
    event RateOracleConfigured(uint128 indexed marketId, address indexed oracleAddress);

    MockRateOracle mockRateOracle;
    uint32 public maturityTimestamp;
    uint128 public marketId;

    function setUp() public virtual {
        rateOracleManager = new RateOracleManagerExtended();
        rateOracleManager.setOwner(address(this));

        mockRateOracle = new MockRateOracle();

        maturityTimestamp = Time.blockTimestampTruncated() + 31536000;
        marketId = 100;

        rateOracleManager.registerVariableOracle(marketId, address(mockRateOracle));
    }

    function test_InitRegisterVariableOracle() public {
        // expect RateOracleRegistered event
        vm.expectEmit(true, true, false, true);
        emit RateOracleRegistered(200, address(mockRateOracle));

        rateOracleManager.registerVariableOracle(200, address(mockRateOracle));
    }

    function test_RevertWhen_RegisterExistingOracle() public {
        vm.expectRevert(abi.encodeWithSelector(IRateOracleModule.AlreadyRegisteredVariableOracle.selector, address(mockRateOracle)));

        rateOracleManager.registerVariableOracle(marketId, address(mockRateOracle));
    }

    function test_RevertWhen_RegisterOracleWrongInterface() public {
        ERC165 fakeOracle = new ERC165();

        vm.expectRevert(abi.encodeWithSelector(IRateOracleModule.InvalidVariableOracleAddress.selector, address(fakeOracle)));

        rateOracleManager.registerVariableOracle(200, address(fakeOracle));
    }

    function test_ConfigureVariableOracle() public {
        // expect RateOracleRegistered event
        vm.expectEmit(true, true, false, true);
        emit RateOracleConfigured(marketId, address(mockRateOracle));

        rateOracleManager.configureVariableOracle(marketId, address(mockRateOracle));
    }

    function test_RevertWhen_ConfigureUnknownOracle() public {
        vm.expectRevert(abi.encodeWithSelector(IRateOracleModule.UnknownVariableOracle.selector, address(mockRateOracle)));

        rateOracleManager.configureVariableOracle(200, address(mockRateOracle));
    }

    function test_RevertWhen_ConfigureOracleWrongInterface() public {
        ERC165 fakeOracle = new ERC165();

        vm.expectRevert(abi.encodeWithSelector(IRateOracleModule.InvalidVariableOracleAddress.selector, address(fakeOracle)));

        rateOracleManager.configureVariableOracle(marketId, address(fakeOracle));
    }

    function test_InitGetRateIndexCurrent() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(marketId, maturityTimestamp);
        assertEq(rateIndexCurrent.unwrap(), 0);
    }

    function test_GetRateIndexCurrentBeforeMaturity() public {
        mockRateOracle.setLastUpdatedIndex(1.001e18 * 1e9);
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(marketId, maturityTimestamp);
        assertEq(rateIndexCurrent.unwrap(), 1.001e18);
    }

    function test_RevertWhen_NoCacheAfterMaturity() public {
        vm.warp(maturityTimestamp + 1);
        vm.expectRevert();
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(marketId, maturityTimestamp);
        // fails because of no cache update
    }

    function test_NoCacheBeforeMaturity() public {
        UD60x18 rateIndexCurrent = rateOracleManager.getRateIndexCurrent(marketId, maturityTimestamp);
    }

    function test_GetRateIndexMaturity() public {
        vm.warp(maturityTimestamp + 1);

        uint256 indexToSet = 1.001e18;

        mockRateOracle.setLastUpdatedIndex(indexToSet * 1e9);
        rateOracleManager.updateCache(marketId, maturityTimestamp);

        UD60x18 rateIndexMaturity = rateOracleManager.getRateIndexMaturity(marketId, maturityTimestamp);
        assertEq(rateIndexMaturity.unwrap(), indexToSet);
    }

    function test_RevertWhen_GetRateIndexMaturityBeforeMaturity() public {
        vm.expectRevert(abi.encodeWithSelector(RateOracleReader.MaturityNotReached.selector));

        rateOracleManager.getRateIndexMaturity(marketId, maturityTimestamp);
    }
}

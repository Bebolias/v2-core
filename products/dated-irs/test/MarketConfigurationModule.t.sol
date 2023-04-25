pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import "../src/modules/MarketConfigurationModule.sol";
import "../src/storage/MarketConfiguration.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";

contract MarketConfigurationModuleExtended is MarketConfigurationModule {
    using MarketConfiguration for MarketConfiguration.Data;

    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
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

contract MarketConfigurationModuleTest is Test {
    using MarketConfiguration for MarketConfiguration.Data;

    MarketConfigurationModuleExtended marketConfiguration;

    event MarketConfigured(MarketConfiguration.Data data);

    address constant MOCK_QUOTE_TOKEN = 0x1122334455667788990011223344556677889900;
    uint128 constant MOCK_MARKET_ID = 100;

    function setUp() public virtual {
        marketConfiguration = new MarketConfigurationModuleExtended();
        marketConfiguration.setOwner(address(this));

        marketConfiguration.configureMarket(MarketConfiguration.Data({ marketId: MOCK_MARKET_ID, quoteToken: MOCK_QUOTE_TOKEN }));
    }

    function test_InitRegisterMarket() public {
        // expect RateOracleRegistered event
        vm.expectEmit(true, true, false, true);
        emit MarketConfigured(MarketConfiguration.Data({ marketId: 200, quoteToken: MOCK_QUOTE_TOKEN }));

        marketConfiguration.configureMarket(MarketConfiguration.Data({ marketId: 200, quoteToken: MOCK_QUOTE_TOKEN }));
    }

    function test_RevertWhen_NoPermisionToRegister() public {
        vm.expectRevert();

        vm.prank(address(1));

        marketConfiguration.configureMarket(MarketConfiguration.Data({ marketId: 200, quoteToken: MOCK_QUOTE_TOKEN }));
    }

    function test_GetMarketConfigurationExistingMarket() public {
        MarketConfiguration.Data memory config = marketConfiguration.getMarketConfiguration(MOCK_MARKET_ID);
        assertEq(config.marketId, MOCK_MARKET_ID);
        assertEq(config.quoteToken, MOCK_QUOTE_TOKEN);
    }

    function test_GetMarketConfigurationUnknownMarket() public {
        MarketConfiguration.Data memory config = marketConfiguration.getMarketConfiguration(200);
        assertEq(config.marketId, 0);
        assertEq(config.quoteToken, address(0));
    }
}

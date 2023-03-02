// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats, StdStorage } from "forge-std/StdCheats.sol";
import "oz/mocks/ERC721EnumerableMock.sol";
import "oz/mocks/ERC721ReceiverMock.sol";
import "oz/interfaces/IERC721Receiver.sol";
import "oz/interfaces/IERC721.sol";

// OZ mocks above already include something called AccountModule so we rename the contract under test to avoid a clash
import { AccountModule as VoltzAccountManager } from "../../src/core/modules/AccountModule.sol";

/// @dev We must make our test contract signal that it can receive ERC721 tokens if it is to be able to create accounts
contract AccountManagerTest is
    Test,
    ERC721ReceiverMock(IERC721Receiver.onERC721Received.selector, ERC721ReceiverMock.Error.None)
{
    /**
     * @dev ERC721 Transfer event. Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    using stdStorage for StdStorage;

    VoltzAccountManager public accountModule;
    ERC721EnumerableMock public mockNft;

    uint128 constant TEST_ACCOUNT_ID = 100;

    /// @dev Invoked before each test case is run
    function setUp() public {
        accountModule = new VoltzAccountManager();
        mockNft = new ERC721EnumerableMock("Mock", "VLTZMCK");
        // uint256 accountTokenSlot = stdstore.target(address(accountModule)).sig("getAccountTokenAddress()").find();
        stdstore.target(address(accountModule)).sig("getAccountTokenAddress()").checked_write(address(mockNft));
    }

    /// @dev Test account creation
    function test_TokenAddress() external {
        assertEq(accountModule.getAccountTokenAddress(), address(mockNft));
    }

    /// @dev Test account creation
    function test_CreateAccount() external {
        vm.expectEmit(true, true, true, true, address(mockNft));

        // We expect an event showing that the new NFT was minted
        emit Transfer(address(0), address(this), TEST_ACCOUNT_ID);
        accountModule.createAccount(TEST_ACCOUNT_ID);
    }

    /// @dev Test account creation
    function test_GetAccountOwner() external {
        accountModule.createAccount(TEST_ACCOUNT_ID);
        assertEq(accountModule.getAccountOwner(TEST_ACCOUNT_ID), address(this));
    }

    /// @dev Test account authorisation
    function test_IsAuthorized() external {
        assertEq(accountModule.isAuthorized(TEST_ACCOUNT_ID, address(this)), false);
        accountModule.createAccount(TEST_ACCOUNT_ID);
        assertEq(accountModule.isAuthorized(TEST_ACCOUNT_ID, address(this)), true);
    }

    /// @dev Each account can only be created once
    function test_CannotCreateSameAccountTwice() external {
        accountModule.createAccount(TEST_ACCOUNT_ID);
        vm.expectRevert("ERC721: token already minted");
        accountModule.createAccount(TEST_ACCOUNT_ID);
    }

    /// @dev Fuzz account creation failing if already exists
    function testFuzz_CannotCreateSameAccountTwice(uint128 x) public {
        accountModule.createAccount(x);
        vm.expectRevert("ERC721: token already minted");
        accountModule.createAccount(x);
    }

    /// @dev Fuzzes account creation succeeding.
    function testFuzz_CreateAccount(uint128 x) external {
        accountModule.createAccount(x);
    }

    /// @dev Test that runs against a fork of Ethereum Mainnet. You need to set `ALCHEMY_API_KEY` in your environment
    /// for this test to run - you can get an API key for free at https://alchemy.com.
    // function testFork_Example() external {
    //     string memory alchemyApiKey = vm.envOr("ALCHEMY_API_KEY", string(""));
    //     // Silently pass this test if the user didn't define the API key.
    //     if (bytes(alchemyApiKey).length == 0) {
    //         return;
    //     }

    //     // Run the test normally, otherwise.
    //     vm.createSelectFork({ urlOrAlias: "ethereum", blockNumber: 16_428_000 });
    //     address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    //     address holder = 0x7713974908Be4BEd47172370115e8b1219F4A5f0;
    //     uint256 actualBalance = IERC20(usdc).balanceOf(holder);
    //     uint256 expectedBalance = 196_307_713.810457e6;
    //     assertEq(actualBalance, expectedBalance);
    // }
}

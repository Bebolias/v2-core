pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/ExecutionModule.sol";
import "../../src/interfaces/external/IWETH9.sol";
import "../../src/modules/ConfigurationModule.sol";
import "../utils/MockWeth.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MT", 18){
        _mint(msg.sender, 1000000000000000000);
    }
}

contract ExtendedExecutionModule is ExecutionModule, ConfigurationModule {
    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }
}

contract ExecutionModuleTest is Test {
    using SafeTransferLib for MockERC20;

    ExtendedExecutionModule exec;
    address core = address(111);
    address instrument = address(112);
    address exchange = address(113);
    address accountNFT = address(114);

    MockWeth mockWeth = new MockWeth("MockWeth", "Mock WETH");

    function setUp() public {
        exec = new ExtendedExecutionModule();
        exec.setOwner(address(this));
        exec.configure(Config.Data({
            WETH9: mockWeth,
            VOLTZ_V2_CORE_PROXY: core,
            VOLTZ_V2_DATED_IRS_PROXY: instrument,
            VOLTZ_V2_DATED_IRS_VAMM_PROXY: exchange
        }));
    }

    function testExecCommand_Swap() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786, 100, 0);

        vm.mockCall(
            instrument,
            abi.encodeWithSelector(
                IProductIRSModule.initiateTakerOrder.selector,
                1, 101, 1678786786, 100, 0
            ),
            abi.encode(100, -100, 25, 55)
        );

        vm.mockCall(
            exchange,
            abi.encodeWithSelector(
                IVammModule.getVammTick.selector,
                101, 1678786786
            ),
            abi.encode(660)
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Settle() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786);

        vm.mockCall(
            instrument,
            abi.encodeWithSelector(
                IProductIRSModule.settle.selector,
                1, 101, 1678786786
            ),
            abi.encode(100, -100)
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Mint() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786, -6600, -6000, 10389000);

        vm.mockCall(
            exchange,
            abi.encodeWithSelector(
                IPoolModule.initiateDatedMakerOrder.selector,
                1, 101, 1678786786, -6600, -6000, 10389000
            ),
            abi.encode(163656, 187267678)
        );

        bytes[] memory output = exec.execute(commands, inputs, deadline);
        (uint256 fee, uint256 im) = abi.decode(output[0], (uint256, uint256));
        assertEq(output.length, 1);
        assertEq(fee, 163656);
        assertEq(im, 187267678);
    }

    function testExecCommand_TwoOutputs() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP)),
            bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
        );
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(1, 101, 1678786786, -6600, -6000, 10389000);
        inputs[1] = abi.encode(1, 101, 1678786786, 100, 0);

        vm.mockCall(
            exchange,
            abi.encodeWithSelector(
                IPoolModule.initiateDatedMakerOrder.selector,
                1, 101, 1678786786, -6600, -6000, 10389000
            ),
            abi.encode(163656, 187267678)
        );

        vm.mockCall(
            instrument,
            abi.encodeWithSelector(
                IProductIRSModule.initiateTakerOrder.selector,
                1, 101, 1678786786, 100, 0
            ),
            abi.encode(100, -100, 25, 55)
        );

        vm.mockCall(
            exchange,
            abi.encodeWithSelector(
                IVammModule.getVammTick.selector,
                101, 1678786786
            ),
            abi.encode(660)
        );

        bytes[] memory output = exec.execute(commands, inputs, deadline);

        (uint256 fee, uint256 im) = abi.decode(output[0], (uint256, uint256));
        (
            int256 executedBaseAmount,
            int256 executedQuoteAmount,
            uint256 fee1,
            uint256 im1,
            int24 currentTick
        ) = abi.decode(output[1], (int256, int256, uint256, uint256, int24));
        assertEq(output.length, 2);
        assertEq(fee, 163656);
        assertEq(im, 187267678);
        assertEq(executedBaseAmount, 100);
        assertEq(executedQuoteAmount, -100);
        assertEq(fee1, 25);
        assertEq(im1, 55);
        assertEq(currentTick, 660);
    }

    function testExecCommand_Withdraw() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_WITHDRAW)));
        bytes[] memory inputs = new bytes[](1);

        MockERC20 token = new MockERC20();
        token.transfer(address(exec), 100000);
        uint256 initBalanceThis = token.balanceOf(address(this));

        inputs[0] = abi.encode(1, address(token), 100000);

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                1, address(token), 100000
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);

        assertEq(token.balanceOf(address(this)), initBalanceThis + 100000);
        assertEq(token.balanceOf(address(exec)), 0);
    }

    function testExecCommand_Withdraw_Reverted() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_WITHDRAW)));
        bytes[] memory inputs = new bytes[](1);

        MockERC20 token = new MockERC20();
        token.transfer(address(exec), 100000);
        uint256 initBalanceThis = token.balanceOf(address(this));

        inputs[0] = abi.encode(1, address(token), 100000);

        vm.mockCallRevert(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                1, address(token), 100000
            ),
            abi.encode("REVERT_MESSAGE")
        );

        vm.expectRevert();
        exec.execute(commands, inputs, deadline);

        assertEq(token.balanceOf(address(this)), initBalanceThis);
        assertEq(token.balanceOf(address(exec)), 100000);
    }

    function testExecCommand_Deposit() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, address(56), 100000);

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralConfigurationModule.getCollateralConfiguration.selector,
                address(56)
            ),
            abi.encode(
                CollateralConfiguration.Data({
                    depositingEnabled: true,
                    liquidationBooster: 1e3,
                    tokenAddress: address(56),
                    cap: 1e18
                })
            )
        );

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                address(this), 1, address(56), 100000
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_CreateAccount() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(127637236);

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                IAccountModule.createAccount.selector,
                127637236
            ),
            abi.encode()
        );

        vm.mockCall(
            accountNFT,
            abi.encodeWithSelector(
                bytes4(abi.encodeWithSignature("safeTransferFrom(address from, address to, uint256 tokenId)")),
                address(exec), address(this), 127637236
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_TransferFrom() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);

        MockERC20 token = new MockERC20();
        token.transfer(address(56), 500);

        vm.prank(address(56));
        token.approve(address(exec), 50);

        vm.expectCall(
            address(token),
            abi.encodeWithSelector(
                bytes4(abi.encodeWithSignature("transferFrom(address,address,uint256)")),
                address(56), address(exec), 50
            )
        );
        inputs[0] = abi.encode(address(token), 50);

        vm.prank(address(56));
        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_WrapETH() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(20000);

        vm.mockCall(
            address(mockWeth),
            20000,
            abi.encodeWithSelector(IWETH9.deposit.selector),
            abi.encode()
        );
        vm.deal(address(this), 20000);
        uint256 initBalance = address(this).balance;
        uint256 initBalanceExec = address(exec).balance;

        exec.execute{value: 20000}(commands, inputs, deadline);

        assertEq(initBalance, address(this).balance + 20000);
        assertEq(initBalanceExec, address(exec).balance - 20000);
    }

    function testExecMultipleCommands() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)), bytes1(uint8(Commands.V2_CORE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(20000);
        inputs[1] = abi.encode(1, address(56), 100000);

        vm.mockCall(
            address(mockWeth),
            20000,
            abi.encodeWithSelector(IWETH9.deposit.selector),
            abi.encode()
        );
        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralConfigurationModule.getCollateralConfiguration.selector,
                address(56)
            ),
            abi.encode(
                CollateralConfiguration.Data({
                    depositingEnabled: true,
                    liquidationBooster: 1e3,
                    tokenAddress: address(56),
                    cap: 1e18
                })
            )
        );
        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                address(this), 1, address(56), 100000
            ),
            abi.encode()
        );
        vm.deal(address(this), 20000);
        uint256 initBalance = address(this).balance;
        uint256 initBalanceExec = address(exec).balance;

        exec.execute{value: 20000}(commands, inputs, deadline);

        assertEq(initBalance, address(this).balance + 20000);
        assertEq(initBalanceExec, address(exec).balance - 20000);
    }

    function test_RevertWhen_UnknownCommand() public {
        uint256 deadline = block.timestamp + 1;
        uint256 mockCommand = 0x09;
        bytes memory commands = abi.encodePacked(bytes1(uint8(mockCommand)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786, 100, 0);

        vm.expectRevert(abi.encodeWithSelector(
            Dispatcher.InvalidCommandType.selector,
            uint8(bytes1(uint8(mockCommand)) & Commands.COMMAND_TYPE_MASK)
        ));
        exec.execute(commands, inputs, deadline);
    }

}